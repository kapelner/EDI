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
- [ ] TODO-10 (added 2026-09-24, from this session's new `biased_estimate`
  audit check, medium-high confidence, not yet root-caused): `InferenceOrdinalCloglogRegr`'s
  MAIN (observed) fit — `compute_estimate()` itself, not the null-refit
  Bug 1/2 already fixed inside the parametric-bootstrap machinery — shows
  outlier/non-convergence contamination at `model_formula=~.`. At
  `beta_T=0`, median estimate is 0.01 (correct) but mean is 0.123 with
  range −3.72 to +5.29, and 16.6% of null-truth rows show `|estimate|>1`
  for what should be a coefficient near 0 — a right-skewed contamination
  pattern (a fraction of fits hitting quasi-separation/boundary
  non-convergence under the larger `~.` design matrix), not a uniform
  shift. **Possible connection to Bug 1/2, not yet verified**: those bugs
  were fixed specifically inside the *null-refit* call site
  (`simulate_under_lik_null()`'s `fit_null` closures); this finding is in
  a *different* call site, the main/observed fit via `generate_mod()`.
  Concrete next step: check directly whether `generate_mod()`'s main fit
  uses single-start optimization the same way the null-refit did before
  this session's multi-start fix — if so, this may be the same
  vulnerability at a second call site that never received the fix, rather
  than a new bug.
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
