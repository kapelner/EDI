# Fix: Ordinal Cumulative-Link Parametric-Bootstrap Inference — Two Distinct Bugs

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Found
> 2026-09-23, following up on the un-triaged bulk of
> `audit_comprehensive_results.R`'s `bad_type1_error` findings (see memory
> `project_stale_worker_cache_resampling_bug_20260922` for the audit
> infrastructure this was found through). Slated for
> `release_v1_0_5.md → TODO-16` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-38`, bug-fix/feature split).

Investigating why `InferenceOrdinalCloglogRegr$compute_param_bootstrap_pval()`
rejects a true null 60% of the time (audit finding: 49% over 726 rows,
z=54.6) turned up **two separate, unrelated bugs**, only one of which is
fixed so far.

## Bug 1 — FIXED: single-start constrained refit in `fit_null` (same mechanism as the stereotype-logit fix)

Reproduced first via a superficially similar symptom, then found to be a
real but **separate** issue from what's actually causing the 60% Type-I
error (see Bug 2). `InferenceOrdinalCloglogRegr`'s `get_likelihood_test_spec()`
and `simulate_under_lik_null()` both have a `fit_null(delta, start)` closure
that runs a single-start delta-constrained refit — exactly the same
vulnerability already found and fixed in
`InferenceOrdinalStereotypeLogitRegr` this session (see memory
`project_stereotype_multimodal_likelihood_20260921` and
`multimodal_log_liks.md`): a cold/single-start constrained optimizer can
stall in a worse local optimum than the unconstrained fit, inflating the LR
statistic at the true value and biasing `compute_lik_ratio_two_sided_pval()`/
`compute_lik_ratio_bootstrap_two_sided_pval()`/Bartlett-approx toward
rejection.

**Fixed** (`inference_ordinal_cloglog.R`): both `fit_null` closures now also
try a second start — the unconstrained fit's own parameters with the
treatment coordinate set to the target value (nudged `+1e-3`, since the
solver reports `converged = FALSE` when started exactly at an optimum) —
and keep whichever converged fit reaches the lower `neg_loglik`. Same
pattern as the stereotype-logit fix, including the sign convention this
class uses (`fixed_values = -delta`/`-d`, matching its own `-attempt$fit$b[1]`
public-facing sign flip elsewhere in the file).

**Verification note (important process finding, not just a result):**
verifying this took three attempts because of two false negatives, not
because the fix was wrong:
1. `deparse(Generator$private_methods$fn)` on an R6 class built via
   `define_inference_class()`'s two-step "interim class →
   `inference_component_source_parts()` → lazy component registry →
   composed class" pattern (used by `OrdinalCloglogLikelihood`, unlike the
   directly-defined `InferenceOrdinalStereotypeLogitRegr`) does **not**
   reflect the edited source, even after `pkgload::load_all(reset=TRUE)`,
   a manual `populate_inference_component_registry()` re-run, and a real
   `R CMD INSTALL` by the user. The **instance**-bound method
   (`instance$.__enclos_env__$private$fn`) does correctly reflect the edit.
   Root cause of the generator-vs-instance discrepancy not tracked down;
   worth remembering for any future edit to a lazily-loaded component's
   methods — check the instance, not the generator, or this looks like a
   silent no-op.
2. Even once verified present at the instance level, the true-null repro
   (`compute_param_bootstrap_pval`) gave byte-for-byte identical p-values
   before and after. This is because `compute_param_bootstrap_pval()` never
   calls the constrained `fit_null` at all (see Bug 2) — the fix is real and
   likely helps `compute_lik_ratio_two_sided_pval`/
   `compute_lik_ratio_bootstrap_two_sided_pval`/Bartlett-approx, but was
   never going to move the specific number I was checking it against.
   **Not independently re-verified against those three methods** — TODO-1
   below.

## Bug 2 — ROOT CAUSE FOUND, NOT YET FIXED: sign mismatch in the shared ordinal parametric-bootstrap data simulator

This is the actual cause of the 60% Type-I error reproduced on
`compute_param_bootstrap_pval`, and is a different, more consequential bug:
**not specific to Cloglog, and not specific to the constrained-refit
mechanism at all.**

### The mechanism

`compute_param_bootstrap_estimate_impl()`
(`inference_ext_param_bootstrap_estimate.R:200-228`, the shared engine behind
`compute_param_bootstrap_pval()`/`compute_param_bootstrap_estimate()`)
simulates each bootstrap replicate via
`private$simulate_under_lik_null(spec, delta = <the observed native
coefficient>, null_fit = full_fit)`, then refits and compares. For Cloglog,
`simulate_under_lik_null()`'s data-generation step (not its `fit_null`
closure — a different part of the same function) calls the **shared**
helper `simulate_param_boot_ordinal_y()`
(`inference_all_abstract_param_boot.R:718-737`), which generates category
probabilities via `cum_probs = cdf_fn(threshold - eta)`, `eta = X %*%
betas`, using `betas` read straight from the model's **native** fitted
parameter vector.

But Cloglog's own `compute_estimate()` (and the `get_likelihood_test_spec()`/
`simulate_under_lik_null()` `fit_null` closures Bug 1 touches) explicitly
negate that native coefficient for public consumption
(`as.numeric(-res$b[1])`) — i.e. the class's own documented generative model
(`P(Y<=k) = 1 - exp(-exp(alpha_k - beta_T*w - beta_X'x))`, this file's own
docstring) is stated in terms of the **public** `beta_T = -b_native`, which
means the model's actual fitted convention is `alpha + b_native*w + ...`,
not `alpha - b_native*w - ...`. `simulate_param_boot_ordinal_y()` uses
`threshold - eta` unconditionally, with no per-class sign adjustment — the
opposite of what this class's native fit actually means.

**Confirmed by direct reproduction**: on a real false-rejection replicate,
the observed native coefficient (`spec$full_fit$params[spec$j]`) is
`-0.383`. Simulating 40 datasets under that value via `simulate_under_lik_null`
and refitting recovers coefficients ranging `+0.14` to `+0.89` (median
around `+0.35`) — clustering near the **negation** of the true value
(`-(-0.383) = +0.383`), not the true value itself, with ordinary `n=100`
sampling spread around it. That is exactly what a sign-flipped generative
formula predicts: every replicate is generated under `-true_value`, so an
unbiased refit recovers something near `-true_value`, not `true_value`.
This corrupts the reflection formula `t_delta = 2*raw_estimate - delta`
(comparing the *correctly-signed* observed estimate against a bootstrap
distribution generated under the *wrong* sign), producing badly miscalibrated
p-values and CIs.

### Scope: audited (TODO-2, 2026-09-23) — narrower than first suspected

Initial suspicion (before auditing) was that this affects the whole
cumulative-link family the `bad_type1_error` triage flagged
(`Cloglog`, `Cauchit`, `PropOddsRegr`, `KKCondAdjCatLogitRegr`,
`AdjCatLogitRegr`, `OrderedProbitRegr`) — wrong, on two counts, found by
reading each class's `generate_mod()`/`compute_estimate()` for the same
`-attempt$fit$b[1]`-style negation Cloglog has, and by re-checking which
`function_run` each class was actually flagged on:

1. **Only `Cloglog` negates its native coefficient.** `Cauchit`,
   `OrderedProbitRegr`, `AdjCatLogitRegr`, and `PropOddsRegr` all return
   `list(b = c(0, attempt$fit$b[1]), ...)` — no negation — and their own
   docstrings state the generative model directly in terms of that
   un-negated native `b` (e.g. Cauchit: `P(Y<=k) = F_Cauchy(alpha_k -
   beta_T*w - ...)` with native `b` = public `beta_T`). For these, native
   already matches what `simulate_param_boot_ordinal_y()`'s `threshold -
   eta` formula assumes — **Bug 2's precondition isn't met, so it doesn't
   apply to them**, regardless of whether they share the helper.
   `InferenceOrdinalKKGLMM`/`KKGEE` (`inference_ordinal_KK_combined.R`) don't
   use the shared helper at all — their own `simulate_under_lik_null()`
   builds `params_null` from `null_fit$alpha/b/log_sigma` and simulates via
   a GLMM-specific mechanism, not `simulate_param_boot_ordinal_y()`.
   `InferenceOrdinalKKCondAdjCatLogitRegr` has no `generate_mod()` at all
   (a conditional-logit fit, different shape entirely).
2. **Most of those five classes' `bad_type1_error` flags are on
   unrelated methods anyway** — re-checking the audit detail: Cauchit and
   OrderedProbitRegr were flagged on `compute_bayesian_bootstrap_two_sided_pval*`
   (a completely different mechanism, `compute_estimate_with_bootstrap_weights`,
   not `simulate_under_lik_null()`); `PropOddsRegr` on
   `compute_rand_bootstrap_two_sided_pval_smoothed` (the `rand_bootstrap`
   resampling operation, also unrelated); `KKCondAdjCatLogitRegr` likewise on
   `compute_bayesian_bootstrap_two_sided_pval*`. None of these three
   mechanisms are Bug 2 (or Bug 1) — they're separate, unexamined findings,
   out of scope for this plan.

**Confirmed affected by Bug 2: only `InferenceOrdinalCloglogRegr`.**
`InferenceOrdinalAdjCatLogitRegr` was flagged on `compute_param_bootstrap_pval`
(z=25.2, the right method family) but does NOT negate its native
coefficient — so if it's genuinely miscalibrated, that's most likely Bug 1
(single-start `fit_null`) rather than Bug 2, since Bug 2's precondition
isn't met. Not yet verified either way (TODO-1 covers re-testing
`AdjCatLogitRegr` once Bug 1's fix is extended to it).

This bug affects every method built on `simulate_under_lik_null()`'s
data-generation step for `InferenceOrdinalCloglogRegr` specifically:
`compute_param_bootstrap_pval`, `compute_param_bootstrap_estimate`,
`compute_param_bootstrap_confidence_interval`,
`compute_lik_ratio_bootstrap_two_sided_pval`, and Bartlett-approx methods.
Whether any *other* class negates the same way (the audit above checked
only the six classes this session's triage happened to flag, not every
ordinal class in the package) is unknown — TODO-2b covers a full
package-wide sweep before this is considered closed.

## Proposed fix (not yet applied)

Two options:

**Option A — per-class sign parameter on the shared helper.** Add a
`sign` (or `native_sign_matches_public`) argument to
`simulate_param_boot_ordinal_y()` that each caller passes based on whether
its own native fit convention matches the public-facing parameter (Cloglog:
`FALSE`/`-1`; a class with no negation: `TRUE`/`+1`). Minimal, explicit,
but relies on each class's author getting the flag right — the exact kind
of per-class fact this package's registries usually try to centralize
rather than duplicate.

**Option B — pass the native (unflipped) value consistently.** Since
`null_fit$params` already carries the native parameterization (that part is
correct), and the bug is specifically that the SIMULATOR's formula direction
doesn't match what "native" means for this class, an alternative is to fix
the formula sign at the call site (inside each class's own
`simulate_under_lik_null()`, before calling the shared helper) by negating
the relevant slice of `params_null` for classes where native != public, so
the shared helper's `threshold - eta` formula stays universal and each class
corrects its own inputs to match. Slightly more code per class, but keeps
the shared helper's contract (`params_null` must already be in
"`threshold - eta`" convention) simple and uniform, closer to this
package's general preference for fixing the fact in one place per class
rather than adding a flag whose meaning has to be remembered at every call
site.

No recommendation made yet between A and B — needs the per-class sign audit
(TODO-2) first to know how many classes are actually affected and whether
they're uniform.

## TODOs

- [ ] TODO-1: Verify Bug 1's fix (already applied) actually helps
  `compute_lik_ratio_two_sided_pval()`, `compute_lik_ratio_bootstrap_two_sided_pval()`,
  and Bartlett-approx on `InferenceOrdinalCloglogRegr` — not yet checked
  independently of the `compute_param_bootstrap_pval` repro that turned out
  to be Bug 2. Use the same true-null-reject-rate style repro as the
  stereotype-logit fix.
- [x] TODO-2 (2026-09-23, completed): Read all 6 originally-suspected
  classes' `generate_mod()`/`compute_estimate()` for the same
  `-attempt$fit$b[1]`-style negation Cloglog has, and cross-checked which
  `function_run` each was actually flagged on. Result: only
  `InferenceOrdinalCloglogRegr` both negates AND was flagged on a
  `simulate_under_lik_null()`-dependent method
  (`compute_param_bootstrap_pval`) — see "Scope" above for the full
  per-class breakdown. `InferenceOrdinalAdjCatLogitRegr` was flagged on the
  right method family but doesn't negate (likely Bug 1, not Bug 2, pending
  TODO-1's extension). The other four classes' flags are on unrelated
  mechanisms (Bayesian bootstrap / rand_bootstrap), out of scope here.
- [ ] TODO-2b: TODO-2 only checked the 6 classes this session's audit
  happened to flag on `bad_type1_error`, not every class in the package
  that might share `simulate_param_boot_ordinal_y()` with a negating
  native convention (a class with no `bad_type1_error` finding could still
  be miscalibrated if nothing forced a wrong-signed replicate to be
  extreme enough to flag, e.g. small `n` or few audited rows). Grep every
  ordinal class for the shared helper and the negation pattern together
  before considering this bug fully scoped.
- [ ] TODO-3: Implement Option A or B (undecided — see "Proposed fix")
  for `InferenceOrdinalCloglogRegr`; extend to whatever TODO-2b finds.
- [ ] TODO-4: Re-run this plan's exact repro
  (`InferenceOrdinalCloglogRegr$compute_param_bootstrap_pval(delta=0)`,
  25+ reps, `n=100`, true null) and confirm reject rate returns to ~0.05;
  repeat for every other confirmed-affected class.
- [ ] TODO-5: Check whether Bug 2 also explains any of the `low_power`
  findings for these classes (a systematically wrong-signed bootstrap
  distribution could suppress power at nonzero `beta_T` just as it inflates
  Type-I error at zero) — not checked yet, the investigation stopped once
  Type-I error was explained.
- [ ] TODO-6: Regenerate `comprehensive_tests` CSV rows for every affected
  class's parametric-bootstrap-family methods once both bugs are fixed and
  installed, then re-audit.
- [ ] TODO-7: Note the generator-vs-instance verification gotcha (see Bug
  1's "Verification note") somewhere durable if a lazily-loaded component
  gets edited again — checking `Generator$private_methods` after
  `pkgload::load_all()` (or even a real reinstall, in this session's case)
  is not a reliable way to confirm an edit took effect for this component
  pattern; check an instantiated object's bound method instead.
- [ ] TODO-8 (added 2026-09-24, from the new `low_coverage` audit check —
  two-sided exact-binomial test, H0: coverage=0.95): **CI-coverage
  cross-check for this plan's confirmed/suspected classes.**
  `InferenceOrdinalCloglogRegr` shows severe undercoverage (0.46 on
  `compute_param_bootstrap_confidence_interval`, n=752) — directly
  consistent with Bug 2 (the same `simulate_param_boot_ordinal_y()` sign
  mismatch corrupting the null-refit distribution this CI is built from);
  TODO-4's re-run should check this CI method's coverage, not just the
  p-value's reject rate, once Bug 2 is fixed. `InferenceOrdinalAdjCatLogitRegr`
  and `InferenceOrdinalCauchitRegr` were ALSO flagged by the coverage
  audit (`AdjCatLogitRegr`: 0.20 on `compute_bayesian_bootstrap_confidence_interval_wald`,
  n=110; `Cauchit`: 0.48-0.53 across `wald`/`score`/`lik_ratio`/
  `bayesian_bootstrap` simultaneously) but a same-day follow-up
  investigation could NOT verify either: the exact `AdjCatLogitRegr` cell
  returned zero rows on a fresh CSV query (likely stale/shifted data —
  multiple sessions have been concurrently rewriting these result files
  this session; needs a fresh audit re-run before investigating further),
  and the `Cauchit` check queried pooled across `model_formula` when the
  finding may be formula-specific (the same pooling-hides-the-signal
  mistake this session's own `InferenceContinLin` investigation warned
  about elsewhere) — genuinely unresolved, not ruled in or out.
- [ ] TODO-9 (added 2026-09-24, same source as TODO-8): `InferenceOrdinalKKCondAdjCatLogitRegr`
  shows the most severe coverage collapse found in this whole audit sweep
  (0.083 on `compute_bayesian_bootstrap_confidence_interval_basic`,
  n=109 — essentially never covers). `coverage_truth` is 100% populated
  with sensible collapsible-scale values (0, 0.5, matching raw `beta_T`
  directly, no MC-adjustment needed) — ruling out a truth-mismatch
  explanation. This is the CI-side manifestation of the exact same
  `compute_bayesian_bootstrap_two_sided_pval*` flag TODO-2 already found
  for this class and explicitly left as "unrelated mechanism, out of
  scope" — still unrelated to Bug 1/2, still unexamined. The shared
  Bayesian-bootstrap machinery
  (`inference_all_abstract_bayesian_bootstrap.R`'s CI-construction
  dispatcher and Dirichlet-weight generator) was read and looks
  textbook-correct (standard Rubin 1981 Bayesian bootstrap, proper
  cluster/matched-unit handling) — no defect found there. Real cause is
  likely in this specific class's own `compute_estimate_with_bootstrap_weights()`
  override (not read) or something about its conditional-logit fit under
  resampled weights specifically (this class has no `generate_mod()` at
  all — a conditional-logit fit, a different shape entirely from the
  cumulative-link classes Bug 1/2 actually fix). Needs its own
  investigation, not a natural fit for this plan's existing TODOs — could
  become its own plan file once someone reads that class-specific
  override.
- [x] TODO-10 (added 2026-09-24, from this session's new `biased_estimate`
  audit check; **CONFIRMED 2026-09-24, high confidence, root cause
  found, not yet fixed**): `InferenceOrdinalCloglogRegr`'s
  MAIN (observed) fit — `compute_estimate()` itself, not the null-refit
  Bug 1/2 already fixed inside the parametric-bootstrap machinery — shows
  outlier/non-convergence contamination at `model_formula=~.`. At
  `beta_T=0`, median estimate is 0.01 (correct) but mean is 0.123 with
  range −3.72 to +5.29, and 16.6% of null-truth rows show `|estimate|>1`
  for what should be a coefficient near 0 — a right-skewed contamination
  pattern (a fraction of fits hitting quasi-separation/boundary
  non-convergence under the larger `~.` design matrix), not a uniform
  shift.

  **Root cause CONFIRMED**: `generate_mod()`
  (`inference_ordinal_cloglog.R:229-286`) — the MAIN/observed fit — makes
  exactly one call to `fast_ordinal_cloglog_regression_with_var_cpp()`
  with one warm-start, wrapped only in QR column-dropping retries, no
  multi-start logic at all. Contrast with the two already-fixed `fit_null`
  closures (lines 137-168, 183-210, Bug 1 above), which now try two starts
  (prior warm-start + unconstrained-fit-perturbed start) and keep
  whichever converged fit reaches the lower `neg_loglik`. `generate_mod()`
  never received this fix — the same single-start-stalls-in-a-bad-local-
  optimum vulnerability sits unpatched at this second call site, exactly
  as hypothesized. **Concrete, scoped, easily fixable**: apply the same
  two-start-keep-lower-`neg_loglik` pattern to `generate_mod()`'s fit
  call. Slated `release_v1_5_0.md → TODO-11`.
- [ ] TODO-11 (added 2026-09-24, from a dedicated cross-class ordinal
  re-audit fork, medium confidence — pattern confirmed real, shared
  mechanism NOT confirmed): `InferenceOrdinalContRatioRegr` and
  `InferenceOrdinalPartialProportionalOddsRegr` show an **identical
  shape**: all asymptotic/direct-SE families (`wald`/`asymp`/etc.)
  undercover at ~0.82 on large samples (1718-1753 rows, a real signal,
  not sampling noise), while every resampling-family method for both
  classes covers fine (0.90-0.99). Checked inheritance directly for both
  — `inherit = Inference`, no shared intermediate base class, different
  source files — so **no shared mechanism is confirmed**; this may be two
  independent SE bugs that happen to produce the same symptom, not one
  bug in shared code. Needs separate root-causing per class (start with
  whichever asymptotic-SE derivation looks more likely to have a sign/
  scale error on direct read).
  - `InferenceOrdinalRidit` shows the same shape, milder (~0.87
    coverage on asymptotic families) — lower priority, not separately
    investigated.
  - `InferenceOrdinalKKCLMM` is only mildly low (~0.94, borderline) —
    likely not worth pursuing on its own. **Correction 2026-09-24**: a
    prior note here treated it as a `TODO-28` candidate (shared
    `cached_design_matrix` staleness), but a direct re-check ruled that
    out — `InferenceOrdinalKKCLMM` and its 3 link-function subclasses
    never override `supports_reusable_bootstrap_worker()` (inherits the
    base `FALSE`), so every bootstrap draw gets a fresh
    `duplicate()`-based worker with no stale-cache exposure; see
    `bootstrap_worker_stale_design_matrix.md`'s "Ruled out 2026-09-24"
    section. This mild undercoverage remains genuinely unexplained.
  - `InferenceOrdinalJonckheereTerpstraTest` has no CI-producing methods;
    a flagged `biased_estimate` cell for it was out of scope for that
    fork and remains uninvestigated.

- [ ] TODO-12 (added 2026-09-24, found via direct code comparison against
  this plan's own already-fixed Bug 1 — high confidence, not yet
  reproduced): **`InferenceOrdinalContRatioRegr`'s likelihood-ratio
  `fit_null` is still single-start — the exact Bug-1 vulnerability, never
  patched for this class.** `get_likelihood_test_spec()`'s `fit_null`
  closure (`inference_ordinal_stereotype_logit.R:748-762`, in
  `OrdinalContinuationRatioLikelihoodSource`) calls
  `fast_continuation_ratio_regression_cpp()` exactly once per delta, from
  a single warm start (`start %||% private$get_fit_warm_start_for_length(...)`),
  with no fallback/retry and no comparison against a second start. This is
  structurally identical to the pre-fix Stereotype-logit `fit_null` (see
  "Bug 1" above) — same delta-constrained-refit multimodality risk this
  plan already diagnosed and fixed for the Stereotype sibling by trying a
  second start (`full_start`: full-fit params with the treatment
  coordinate pinned to `delta`, nudged by `1e-3`) and keeping whichever
  refit reaches the lower `neg_loglik`
  (`inference_ordinal_stereotype_logit.R:313-334`). Directly explains the
  candidate mechanism for `InferenceOrdinalContRatioRegr`'s 9-family
  `pval_miscalibration` audit finding (parametric-bootstrap/
  likelihood-ratio methods specifically — a stalled-in-a-worse-local-optimum
  null refit inflates the LR statistic and biases p-values low, same as
  Bug 1's original symptom). Fix: apply the identical two-start-then-
  `which.min(neg_loglik)` pattern to this `fit_null`, reusing the same
  `full_start` construction (note `j_treat`/`ctx$full_params` are already
  in scope here). Then reproduce and confirm against this class's audit
  CSVs the same way TODO-1 verified Bug 1's fix.

- [ ] TODO-13 (added 2026-09-24, cross-class reconciliation fork against
  a fresh full-package audit re-run — high confidence pattern, mechanism
  NOT yet pinned): **TODO-11's "asymptotic-SE-broken, resampling-fine"
  shape now confirmed across 5 classes, not 2** — strong evidence of a
  SHARED mechanism, contradicting TODO-11's original "no shared mechanism
  confirmed" caveat. Fresh numbers: `InferenceOrdinalContRatioRegr`
  asymp/wald/score/gradient/lik_ratio all 0.821-0.832 (matches TODO-11's
  original ~0.82); `InferenceOrdinalPartialProportionalOddsRegr` 0.817-0.868
  (matches); `InferenceOrdinalCauchitRegr` asymp/wald/gradient/lik_ratio/score
  0.798-0.825 (same magnitude, same shape — NEWLY confirmed as a cluster
  member); `InferenceOrdinalAdjCatLogitRegr` asymp/wald/gradient/lik_ratio/score
  0.823-0.836 (same magnitude — NEWLY confirmed cluster member). All four
  classes' resampling-family CIs are fine-to-over (0.90-1.00) in the same
  data. Given 4 independently-implemented classes (per TODO-2's audit:
  `ContRatioRegr` and `PartialProportionalOddsRegr` in one file,
  `Cauchit`/`AdjCatLogitRegr` elsewhere, no shared intermediate base
  class) show the IDENTICAL 0.80-0.84 magnitude on the IDENTICAL family
  of methods (`asymp`/`wald`/`score`/`gradient`/`lik_ratio` — i.e. every
  method built on the class's own information-matrix-based SE, as opposed
  to a resampled SE), the most likely explanation is a shared **package-
  level** SE/CI-construction routine common to ordinal cumulative-link
  classes' non-resampling inference (e.g. a shared Fisher-information
  extraction or shared asymp/wald/score/gradient CI dispatcher used by
  `Inference`'s ordinal base machinery) — not 4 coincidentally-identical
  independent bugs. **Next step, not yet done**: find the shared function
  these 5 function_run families actually route through for ordinal
  cumulative-link classes (likely something in `inference_all_abstract.R`
  or an ordinal-specific shared SE helper) and check it directly for a
  concrete defect (wrong information-matrix term, wrong link
  second-derivative, wrong critical value, etc.) — this is now the
  single most promising unexplained lead in the whole ordinal cluster.
  `InferenceOrdinalRidit` (previously in TODO-11's cluster at ~0.87) could
  not be re-checked this pass — its raw result rows were pruned by this
  session's `prune_stale_result_rows.R --apply` run (9188 stale ok-rows
  removed) and need a fresh `comprehensive_tests.R` run to regenerate
  before re-auditing. `InferenceOrdinalKKCLMM` remains separately mild
  (~0.91, `TODO-28` already ruled out) and is NOT folded into this
  cluster (different, milder magnitude, no evidence of the same
  mechanism).
  **Follow-up 2026-09-24 (leading hypothesis found, NOT empirically
  confirmed — medium confidence):** traced all four classes' asymp/wald/
  score/gradient/lik_ratio dispatch to the shared machinery in
  `inference_all_abstract_asymp_lik.R` (`compute_asymp_confidence_interval`'s
  `switch(private$testing_type, ...)`) and `inference_ext_information_matrix.R`
  (`compute_standard_error_from_information_matrix`/
  `compute_variance_from_information_matrix`). Both read as mathematically
  standard (diagonal-of-inverse-information variance, with a positive-
  definiteness guard and a `solve()`/`qr.solve()` fallback) — no wrong
  information-matrix term, wrong link second-derivative, or wrong critical
  value found. `Cauchit`/`AdjCatLogitRegr` inherit the shared
  `InferenceAsympLikStdModCache` component and set `df = NA_real_`
  (normal-quantile CI); `ContRatioRegr` (in `inference_ordinal_stereotype_logit.R`)
  also sets `df = NA_real_`; `PartialProportionalOddsRegr` sets
  `df = private$n - 1`. On samples in the thousands (TODO-13's rows are
  1718-1753), t-vs-normal is negligible — **the df/critical-value
  difference cannot explain a ~13-15 percentage-point coverage gap**, so a
  df bug is ruled out as the (sole) mechanism.
  **Magnitude analysis**: to produce 0.80/0.82/0.84 observed coverage
  from a nominal-95%-target CI with a correctly-centered estimate implies
  the true SE is **~1.40-1.53× the nominal (computed) SE** — i.e. the
  computed information-matrix-based SE is undersized by roughly a third
  to a half, not a small rounding-level defect.
  **Leading hypothesis**: these are all pure model-based (Fisher-
  information) Wald/likelihood SEs, which are asymptotically valid under
  iid/completely-randomized sampling but have no mechanism to account for
  EDI's actual randomization design (matched-pair, blocked, KK-family,
  etc.) when the audit pools results across all tested designs — the
  model SE reflects only within-model sampling variability, not any
  extra variance (or covariance structure) the randomization mechanism
  itself induces. This would explain uniform undercoverage across
  wald/score/gradient/lik_ratio simultaneously (all four route through
  the same underlying Fisher-information/likelihood machinery, unlike
  the resampling-family methods which empirically incorporate whatever
  variance the actual resampling exhibits). **Correction, not corroboration**:
  a parallel investigation (`investigate_contin_quantile_regr_coverage.md`)
  looked at the exact same design-pooling hypothesis for
  `InferenceContinQuantileRegr`'s `"nid"` sandwich SE and **directly
  REFUTED it** via real design-stratified data — plain `Bernoulli` design
  showed essentially the same undercoverage magnitude (0.908-0.924) as
  structured designs (`FixedBlocking` 0.875-0.920,
  `FixedMatchingGreedy` 0.891-0.942), which a design-incompatibility
  mechanism cannot produce (Bernoulli should have been near-nominal if
  the SE only breaks under non-iid designs). That fork's revised leading
  candidate is dataset-shape/skewness sensitivity instead. **This
  earlier note's claim of corroboration was written before that
  refutation was available and is wrong as stated** — the design-pooling
  hypothesis for THIS (ordinal) cluster remains an open, independently-
  standing hypothesis, not one with cross-class support. Do not cite the
  ContinQuantileRegr finding as supporting evidence for it going forward;
  if anything it's a data point against the design-pooling mechanism
  being a general explanation across response types.
  **RESOLVED 2026-09-24 (follow-up fork, high confidence): design-pooling
  hypothesis definitively REFUTED, and the real mechanism found — a
  harness truth-registry gap, not a package SE bug, for 3 of the 4
  classes.**

  The result CSVs stabilized enough for a direct design-stratified query
  this pass. Filtering to the 5 asymp-family CI methods across all 4
  classes (29,748 rows): `Bernoulli` design shows **0.832** coverage,
  essentially identical to the pooled non-Bernoulli average (**0.820**),
  and sits mid-pack among individual structured designs (range
  0.746-0.864 across `FixedBinaryMatch`/`FixedBlocking`/
  `FixedMatchingGreedy`/`FixediBCRD`/`KK21stepwise`/`SPBR`). A design-
  incompatibility mechanism predicts Bernoulli should be near-nominal
  (~0.95) while structured designs undercover — that is not what the
  data shows. **Design-pooling is ruled out**, matching (not
  "corroborating" — see the correction two paragraphs up) the same
  refutation already found for `InferenceContinQuantileRegr`.

  **Real mechanism**: none of `InferenceOrdinalContRatioRegr`,
  `InferenceOrdinalCauchitRegr`, `InferenceOrdinalAdjCatLogitRegr`, or
  `InferenceOrdinalPartialProportionalOddsRegr` appear in
  `comprehensive_tests.R`'s `COVERAGE_CLOSED_FORM`/`COVERAGE_MC_SPEC`
  truth registries, so all 4 fall back to raw `beta_T_val` as ground
  truth. The harness's ordinal DGP (`comprehensive_tests.R:3107/3129`,
  `p_t = plogis(qlogis(p_base) + bt + eps)`) generates outcomes under a
  **cumulative-logit (proportional-odds) shift model** — this is the
  EXACT same mechanism already confirmed responsible for
  `InferenceOrdinalRidit`'s coverage bug (see the comment immediately
  above this entry in the registry, "found 2026-09-06"): raw `beta_T` is
  only the correct truth for an estimator whose target parameter is
  literally the cumulative-logit log-odds shift.

  Checked each of the 4 classes' actual generative model against this:
  - **`InferenceOrdinalCauchitRegr`**: uses `stats::pcauchy` as its link
    (confirmed at `inference_ordinal_cauchit.R:114`, and its own docstring
    at `:266-273` states the model explicitly as a cauchit-link cumulative
    model) — genuinely misspecified relative to the logit-link DGP. Under
    model misspecification the MLE converges to a KL-divergence-minimizing
    pseudo-true value, not `beta_T` — **CONFIRMED same class of bug as
    Ridit.**
  - **`InferenceOrdinalAdjCatLogitRegr`**: adjacent-category logit is a
    genuinely different ordinal model family from proportional-odds/
    cumulative-logit despite the shared word "logit" in the name — the
    package's own documentation (`inference_ordinal_stereotype_logit.R:463`)
    explicitly groups "proportional-odds/adjacent-category/continuation-
    ratio" as three *distinct* families. **CONFIRMED same class of bug.**
  - **`InferenceOrdinalContRatioRegr`**: continuation-ratio is likewise a
    distinct sequential/hazard-style model, not cumulative-logit
    (`fast_continuation_ratio_regression_cpp`,
    `inference_ordinal_stereotype_logit.R:570-693`). **CONFIRMED same
    class of bug.**
  - **`InferenceOrdinalPartialProportionalOddsRegr`**: uses
    `VGAM::cumulative(link = "logitlink", parallel = ...)`
    (`inference_ordinal_partial_proportional_odds.R:536,562,594`) — the
    **SAME logit link as the DGP**, and a strict generalization of the
    proportional-odds model (relaxes the parallel-lines constraint for
    specific covariates) that nests the true PO-logit model as a special
    case. **This class is correctly specified, NOT explained by the
    truth-mismatch mechanism** — its coverage problem is a genuinely
    separate, still-open issue (new TODO-18, appended at the end of this
    file's TODO list).

  **Fix, and where it belongs**: like the Ridit precedent, the fix is
  adding `InferenceOrdinalCauchitRegr`/`AdjCatLogitRegr`/`ContRatioRegr`
  to `COVERAGE_MC_SPEC` with MC-refit truth (a test-harness change, not
  an EDI package source-code fix — these classes' actual inference is
  not necessarily wrong, only the audit's comparison target was wrong).
  Following this session's established convention for this exact class
  of finding (Ridit, `InferenceSurvivalKMDiff`, `KKGLMM`/`KKCLMMCauchit`
  all filed under `mc_coverage_truth_covariate_mismatch.md` and tracked
  in `release_v1_0_5.md`, not `release_v1_5_0.md`, since `release_v1_5_0.md`
  is scoped to confirmed EDI *source* bugs), this is filed the same way
  — see `mc_coverage_truth_covariate_mismatch.md`'s new TODO-10 and
  `release_v1_0_5.md`'s updated TODO-16 cross-reference, not added to
  `release_v1_5_0.md`.
  **Also checked**: `InferenceOrdinalGCompMeanDiff`'s `TODO-28` candidacy —
  **cleanly REFUTED**. Read `inference_ordinal_gcomp.R` in full:
  `compute_estimate_with_bootstrap_weights()` calls
  `weighted_gcomp_md_from_row_weights()`, which never calls
  `create_design_matrix()` anywhere in the file, and the class has no
  `supports_reusable_bootstrap_worker()` override (inherits the base
  `FALSE`). Not a `TODO-28` candidate at all; its `low_coverage`/
  `biased_estimate` findings need independent root-causing, not
  cross-referencing to `bootstrap_worker_stale_design_matrix.md`.
- [ ] TODO-14 (added 2026-09-24, same reconciliation pass — new, no
  prior coverage in this file): `InferenceOrdinalOrderedProbitRegr` (12
  new findings). Milder broad undercoverage on the asymp/wald/gradient/
  jackknife_wald/lik_ratio/score family (0.914-0.918, less severe than
  TODO-13's cluster) plus resampling-family mostly fine-to-over
  (`m_out_of_n_bootstrap`/`subsampling` 0.978-0.981), BUT one sharp
  outlier: `compute_bayesian_bootstrap_confidence_interval_basic` at
  **0.760** (n=705) — much worse than the rest of this class's own
  findings and worth investigating on its own rather than folding into
  the broader mild pattern. A small `biased_estimate` finding also flags
  `compute_estimate` (+0.0192 bias, ACAT p=3.26e-04) — plausibly ordinary
  finite-sample probit-MLE bias, not separately investigated. Per TODO-2's
  audit, `OrderedProbitRegr` does not negate its native coefficient, so
  `Bug 2` does not apply. Not root-caused; light priority given the milder
  magnitude on the main cluster, but the 0.760 outlier deserves a direct
  look.
- [ ] TODO-15 (added 2026-09-24, same reconciliation pass — reconciles
  `TODO-9`'s pre-pruning numbers against fresh data): `InferenceOrdinalKKCondAdjCatLogitRegr`'s
  exact previously-cited cell (`compute_bayesian_bootstrap_confidence_interval_basic`
  at 0.083, n=109) no longer appears in a fresh audit run — the closest
  current findings are `compute_bayesian_bootstrap_confidence_interval`
  (unsuffixed, 0.890, n=109) and `compute_bootstrap_confidence_interval_studentized`
  (0.830, n=53), both meaningfully less severe than the original 0.083.
  Likely explanation: this session's `prune_stale_result_rows.R --apply`
  run removed old degenerate rows for other classes broadly, and/or the
  underlying result CSVs have simply accumulated more (differently
  distributed) rows since TODO-9 was written — not confirmed which. TODO-9
  itself remains open and its root-cause investigation (this class's own
  `compute_estimate_with_bootstrap_weights()` override, not yet read) is
  still the right next step; treat the new, less-severe numbers as an
  update, not a resolution.
- [ ] TODO-16 (added 2026-09-24, same reconciliation pass — likely
  benign): `InferenceOrdinalPropOddsRegr`'s 3 new findings
  (`compute_bootstrap_confidence_interval_basic` 0.982,
  `compute_m_out_of_n_bootstrap_confidence_interval` 0.986,
  `compute_subsampling_confidence_interval` 0.983) are all mild
  OVER-coverage on resampling-family methods only — same shape as this
  session's other closed-as-benign findings (RiskDiff/RiskRatio
  low_power, IncidLogRegr/ProbitRegr low_coverage). Likely not a bug;
  not investigated further given the low severity.
- [ ] TODO-17 (added 2026-09-24, same reconciliation pass — connects an
  existing TODO to fresh data, not new): `InferenceOrdinalCloglogRegr`'s
  10 new `low_coverage` findings span `asymp`/`wald`/`score`/`gradient`/
  `lik_ratio`/`jackknife_wald` (0.860-0.912, undercoverage) plus 3
  resampling methods (`bootstrap_basic`/`m_out_of_n_bootstrap`/
  `subsampling`, all mild OVER-coverage 0.981-0.986) and
  `bayesian_bootstrap_confidence_interval_wald` (0.807). Notably,
  `compute_param_bootstrap_confidence_interval` — the method `TODO-8`
  already flagged at severe 0.46 undercoverage, directly tied to `Bug 2`'s
  sign mismatch — does NOT appear in this fresh new-findings list at all;
  not confirmed whether that means it's been resolved, its rows were
  pruned, or it simply didn't regenerate fresh rows this run. Given
  `Bug 2` is confirmed but NOT YET FIXED, `compute_param_bootstrap_confidence_interval`
  should still be badly undercovering — this needs a direct fresh check,
  not an assumption either way. Separately, most of these 10 new findings
  (the `asymp`/`wald`/`score`/`gradient`/`lik_ratio` family specifically)
  more plausibly connect to `TODO-10`'s already-flagged MAIN-fit outlier
  contamination (quasi-separation/boundary non-convergence under `~.`) —
  those methods use the observed fit directly, not the null-refit `Bug 1`/
  `Bug 2` touch — so a badly-estimated point estimate with an otherwise
  correctly-sized CI naturally undercovers. Not confirmed, but a more
  parsimonious explanation than treating this as a third bug.

- [x] TODO-18 (added 2026-09-24, from the TODO-13 design-pooling
  follow-up; **RESOLVED 2026-09-24, high confidence, test-harness gap,
  NOT a package bug**): `InferenceOrdinalPartialProportionalOddsRegr`'s
  asymptotic-family `low_coverage` findings (pooled: 0.817-0.868).

  **The VGAM SE-extraction hypothesis is moot, not just refuted**:
  `comprehensive_tests.R:3920` never passes a `nonparallel` argument when
  instantiating this class, so `private$nonparallel` is always its default
  `character(0)` in every harness run — confirmed by reading
  `initialize()` (`inference_ordinal_partial_proportional_odds.R:56,65`)
  and `fit_partial_proportional_odds_from_covariates()` (`:382-411`),
  which takes the `fit_fast_proportional_odds()` branch whenever
  `nonparallel_covars` is empty and never reaches the `VGAM::vglm` path at
  all in this harness. So this class is, in every tested case, fitting
  via the exact same shared kernel (`fast_ordinal_regression_with_var_cpp()`,
  `res$ssq_b_j`) as `InferenceOrdinalPropOddsRegr` (confirmed by grep —
  same function call, same variance field, in
  `inference_ordinal_proportional_odds.R:243,251`) — there is no
  partial/VGAM-specific extraction bug to find.

  **Real mechanism, found by `beta_T`-stratifying instead of pooling**
  (the file's own established "pooling hides the signal" lesson, applied
  here): queried `comprehensive_tests_results_nc_1_ordinal.csv` directly
  for `compute_asymp_confidence_interval`/`compute_wald_confidence_interval`,
  split by `design_formula` tag AND `beta_T`:

  | formula | beta_T | coverage | n |
  |---|---|---|---|
  | `~1` | 0 | 0.954 | 504 |
  | `~1` | 0.5 | 0.948 | 250 |
  | `~.` | 0 | 0.949 | 649 |
  | `~.` | 0.5 | **0.283** | 350 |

  Coverage is nominal in every cell except `(~., beta_T=0.5)`, where it
  collapses catastrophically. This is the textbook signature of
  **non-collapsibility of a cumulative-logit treatment coefficient under
  covariate adjustment**: adding covariates to a nonlinear-link (logit)
  model changes the conditional log-odds treatment effect relative to the
  marginal one, even for a correctly-specified, correctly-fitted model —
  raw `beta_T` (the value used to *generate* the data) is only the exact
  correct truth at `beta_T=0` (0 is invariant to conditioning) or under
  `~1` (no covariates to condition on); at nonzero `beta_T` under `~.` it
  is not. This is the SAME class of harness-truth-registry gap as
  `TODO-13`'s resolution above (and `InferenceOrdinalRidit`'s original
  2026-09-06 fix) — this class needs `COVERAGE_MC_SPEC` treatment too
  (MC-refit truth at nonzero `beta_T` under `~.`), not a source-code fix.
  The pooled 0.817-0.868 figures from the original finding were simply a
  blend of the near-nominal `beta_T=0` rows and the catastrophic
  `beta_T=0.5`-under-`~.` rows.

  Filed with `mc_coverage_truth_covariate_mismatch.md`'s TODO-10 (which
  already covers `TODO-13`'s 3 sibling classes) and `release_v1_0_5.md`'s
  TODO-16 cross-reference — **not added to `release_v1_5_0.md`**, per
  that file's scope (confirmed EDI source bugs only).

- **`InferenceOrdinalOrderedProbitRegr`'s 0.760 outlier
  (`compute_bayesian_bootstrap_confidence_interval_basic`, `TODO-14`)
  re-examined 2026-09-24**: the deferral to a "shared basic-CI-formula
  defect" was stale — that hypothesis was refuted for a *different* class
  (`InferenceSurvivalDepCensTransformRegr`, `rmst_mismatched_truncation_horizon.md`
  TODO-9) on the grounds that its *unsuffixed* `compute_bayesian_bootstrap_confidence_interval`
  call defaults to `type="percentile"`, not `"basic"`. Checked whether
  that refutation actually transfers here: `comprehensive_tests.R:2700-2701`
  explicitly calls `compute_bayesian_bootstrap_confidence_interval(type =
  bayes_ci_type)` and labels the `function_run` `..._basic` specifically
  when `bayes_ci_type == "basic"` — so `OrderedProbitRegr`'s finding *does*
  genuinely hit the "basic"/reflection formula, a different code path from
  `DepCensTransformRegr`'s. Since that formula was independently confirmed
  textbook-correct (`helper_bootstrap_ci.R:5-22`, read by the
  `DepCensTransformRegr` fork), this outlier is most plausibly the same
  known weakness — the reflection/basic bootstrap method underperforming
  under a skewed/asymmetric bootstrap sampling distribution — applied to
  this class's own bootstrap distribution, not a code defect. **Not
  independently confirmed via direct skewness measurement of this
  specific bootstrap distribution** (out of scope this pass); closing as
  "same known methodological weakness, consistent conclusion," medium
  confidence, no `release_v1_5_0.md` entry (matches the
  `DepCensTransformRegr` closure precedent — a design-choice enhancement
  candidate, not a bug).

- **`TODO-9`, `InferenceOrdinalKKCondAdjCatLogitRegr`, root-caused
  2026-09-24 (medium confidence, mechanism identified, not fully traced)**:
  read `compute_estimate_with_bootstrap_weights()`
  (`inference_ordinal_KK_cond_adj_cat_logit.R:127-142`) directly. It
  **does** call `private$create_design_matrix()` (`:137`) — contradicting
  this TODO's original framing ("no `generate_mod()` at all... real cause
  likely elsewhere"), so `TODO-28` applicability had to be re-checked
  properly (both conditions, not just the call-site match). Checked
  condition 2: the class's own `overrides$private` list
  (`:184-194`) *declares* `supports_reusable_bootstrap_worker`,
  `create_bootstrap_worker_state`, `load_bootstrap_sample_into_worker`,
  and `compute_bootstrap_worker_estimate` as overridden — but none of
  these names have an actual function body anywhere in this file, and
  none of the 4 composed components (`BayesianBootstrap`, `Wald`,
  `OrdinalConditionalLogitPartialLikelihood`, `KKPassThrough`, or
  `KKPassThrough`'s `ConditionalLogitPartialLikelihood` dependency)
  provide them either (checked each component's `provides_private_methods`
  list in `contracts_mixins.R`). **Same pattern already found for
  `InferencePropKKGLMM`**: an `overrides` declaration with no matching
  body falls through to the fully generic base default, which is
  `supports_reusable_bootstrap_worker() = FALSE`
  (`inference_all_abstract_non_param_boot.R:1090-1092`). So this class
  gets a fresh `duplicate()`-based worker every bootstrap draw — `TODO-28`
  is **cleanly ruled out** here too, confirming (not contradicting) the
  original TODO-9 note's conclusion, just via the correct two-condition
  check rather than the (correct, but under-justified) assumption that no
  `create_design_matrix()` call existed.

  **New leading candidate**: when weights aren't effectively constant,
  `compute_estimate_with_bootstrap_weights()` doesn't refit the true
  weighted conditional-logit model — it calls
  `weighted_ordinal_bootstrap_surrogate_fit()` (`:138`), which the
  method's own docstring (`:110-122`) describes as "a fast weighted
  ordinal-logistic surrogate fit... as an approximation to the weighted
  adjacent-category likelihood... trades exact reweighted refitting for
  speed." An approximate (not exact) weighted refit used across every
  bootstrap replicate is a plausible source of systematic distortion in
  the resulting bootstrap distribution's center/spread, which would
  directly corrupt Bayesian-bootstrap and nonparametric-bootstrap CI
  coverage — consistent with this class's severe, resampling-CI-specific
  coverage collapse. **Not confirmed**: the surrogate's specific bias
  direction/magnitude wasn't traced, and it's not yet checked whether
  other classes sharing `weighted_ordinal_bootstrap_surrogate_fit()` show
  the same severity (which would implicate the surrogate itself) or not
  (which would implicate something specific to this class's usage of it,
  e.g. the adjacent-category expansion interacting badly with the
  surrogate's assumptions). Needs its own follow-up investigation before
  this could go in `release_v1_5_0.md`.

## Standing constraints

Same as `multimodal_log_liks.md`/`stale_worker_cache_resampling.md`:
Bug 2's fix changes simulated bootstrap replicates for affected classes,
which changes p-values/CIs computed via those methods — an estimate-changing
fix in the same category as `release_v1_1_0.md`'s TODO-11 exception, needs
the same golden/reference-parity review discipline before shipping. No
`R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn; verify
via `pkgload::load_all(".", compile = FALSE)` **and confirm against an
instantiated object**, per TODO-7 — the generator-level check silently lies
for this class's composition pattern.
