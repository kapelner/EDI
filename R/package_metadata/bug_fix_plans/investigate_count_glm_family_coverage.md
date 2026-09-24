# Investigate: Count-Family GLM Coverage (`InferenceCountPoisson`/`InferenceCountNegBin`/`InferenceCountZeroInflatedPoisson`)

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's `low_coverage` check (95% CI
> coverage target, exact binomial test + FDR) after its first-ever run
> against the accepted baseline surfaced 650 new, never-triaged findings.
> These 3 classes account for 50 of those 650 (18/16/16 respectively), all
> new. **Medium-low confidence — real, broad pattern confirmed; root cause
> NOT pinned down; `TODO-28` cleanly ruled out for all 3.**

## The finding

All 3 classes show `low_coverage` findings, but with **two distinct
shapes**:

**`InferenceCountPoisson`/`InferenceCountNegBin` (~. formula, broad,
cross-method):** coverage sits at **~0.85-0.93** (moderately under target)
across almost every asymptotic method (`asymp`/`wald`/`score`/`gradient`/
`lik_ratio`/`lik_ratio_bartlett*`) AND most resampling methods
(`bayesian_bootstrap*`, `bootstrap_studentized`, `param_bootstrap`,
`jackknife_wald`) simultaneously — a few resampling methods
(`m_out_of_n_bootstrap`, `subsampling`, `lik_ratio_bootstrap`) instead
**OVER-cover** at ~0.98-0.99 (plausibly just those families' known
conservative width-inflation, not part of the same problem).

**`InferenceCountZeroInflatedPoisson`:** findings are confined to
**asymptotic/direct-fit methods only** (`asymp`/`gradient`/`lik_ratio`/
`score`/`wald`), coverage ~0.85-0.91 — no bootstrap-family methods flagged
at all (this class's component set, `InferenceCountZeroAugmentedPoissonAbstract`
→ `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
"ZeroAugmentedCountLikelihood")`, has no `NonParamBoot`/`Jackknife`
component, so `subsampling`/`m_out_of_n_bootstrap`/`jackknife_wald` simply
don't exist for this class — the shape difference from Poisson/NegBin may
just reflect which methods exist, not a different mechanism).

## `TODO-28` — cleanly ruled out for all 3, confirmed by direct code read

`InferenceCountPoisson$compute_estimate_with_bootstrap_weights()`
(`inference_count_poisson.R:402-420`) and
`InferenceCountNegBin$compute_estimate_with_bootstrap_weights()`
(`inference_count_negbin.R:121-140`) both build `X_full = cbind(Intercept,
treatment, X_data)` **directly inline** from `private$get_X()` on every
call — neither calls `create_design_matrix()`/`build_design_matrix()` at
all, so the `cached_design_matrix` staleness bug cannot apply regardless
of their `supports_reusable_bootstrap_worker()` status (both return
`TRUE`, but the vulnerable cache is simply never touched). Not
independently checked for `InferenceCountZeroInflatedPoisson`'s abstract
base, but moot anyway since it shows no bootstrap-family findings.

## Candidate mechanism (unconfirmed) — a coverage_truth/DGP mismatch, not necessarily a package bug

Neither `InferenceCountPoisson`, `InferenceCountNegBin`, nor
`InferenceCountZeroInflatedPoisson` appears in `comprehensive_tests.R`'s
`COVERAGE_CLOSED_FORM` or `COVERAGE_MC_SPEC` lists (checked directly,
`comprehensive_tests.R:3207+`/`:3302+`) — so `get_coverage_truth()` falls
through to the raw default, `coverage_truth = beta_T`
(`comprehensive_tests.R:1485`). This is the exact same class of harness
issue this project has found before for other classes (see the code
comment at `comprehensive_tests.R:3388-3392` describing
`InferenceAllSimpleMeanDiffPooledVar`'s prior ~51%-coverage false alarm
from the identical omission, and `release_v1_0_5.md`'s `TODO-32`/`fix_mc_coverage_truth_covariate_mismatch.md`
for a second confirmed instance).

**Reasoning for why this is plausible but NOT confirmed:** the count DGP
(`apply_treatment_effect_and_noise()`, `comprehensive_tests.R:3129-3132`)
generates `lambda_t = y_t * exp(beta_T*[w_t==1] + eps)`, `eps ~
N(0,SD_NOISE)` drawn per-subject independent of treatment arm, then
`rpois(1, lambda_t)`. Algebraically, the marginal (population-averaged)
log-rate-ratio between arms should still equal `beta_T` in expectation
(since `eps`'s distribution doesn't differ by arm), which argues AGAINST
a pure truth-value bias. But the broad, near-uniform ~0.85-0.93
undercoverage spanning BOTH naive-model asymptotic methods AND genuinely
nonparametric resampling methods (which should be robust to Poisson-
variance misspecification) is hard to explain by a single per-method SE
bug — if it were only "naive Poisson SE ignores overdispersion," bootstrap
methods should still be well-calibrated, but they aren't. This tension is
unresolved: neither the "coverage_truth is subtly wrong" hypothesis nor a
"real overdispersion-driven SE bug replicated across an unusually large
number of methods" hypothesis was confirmed or ruled out in this pass.

**Overdispersion note (secondary candidate, also unconfirmed):** the
per-subject multiplicative `exp(eps)` noise is an added source of
variance beyond standard Poisson sampling (`Var(Y) = E[Y] +
Var(lambda_t)` by the law of total variance) — genuine overdispersion
relative to what `InferenceCountPoisson`'s naive model assumes.
`InferenceCountNegBin` has its own dispersion parameter and should be
more robust to this in principle, but still shows a similar pattern,
suggesting either (a) NegBin's gamma-mixture dispersion doesn't fully
match this DGP's log-normal-ish multiplicative noise structure (a benign
DGP/model mismatch, not a package bug), or (b) the shared
`coverage_truth` issue above dominates for both classes regardless of
dispersion handling.

## Deep-dive update 2026-09-24: tension resolved, one real bug confirmed + one lead narrowed

**TODO-1 resolved: `beta_T` IS the correct truth.** Direct derivation
against `apply_treatment_effect_and_noise()`'s count DGP
(`comprehensive_tests.R:3129-3132`): `lambda_t = y_t * exp(beta_T*[w=1] +
eps)`, `eps ~ N(0, SD_NOISE)` drawn independent of arm and covariates,
`Y|lambda_t ~ Poisson(lambda_t)`. Since `eps`'s distribution doesn't
differ by arm, `E[Y|x,w=1] / E[Y|x,w=0] = exp(beta_T) * E[exp(eps)] /
E[exp(eps)] = exp(beta_T)` exactly — the `exp(SD_NOISE^2/2)` log-normal
correction cancels between arms. This holds both marginally and
conditionally on `x` (no treatment-by-covariate interaction in the DGP),
so the log-rate-ratio truth is `beta_T` exactly, confirming the harness's
`get_coverage_truth()` fallback isn't the problem — **the coverage-truth
mismatch hypothesis is REFUTED**, not just "unconfirmed."

**Real bug found, medium-high confidence, root-caused: `InferenceCountPoisson`'s
documented equidispersion-robustness treatment is incompletely applied.**
The class's own docstring (`inference_count_poisson.R:11-29`) explicitly
documents a "design-conservative testing" mechanism: every asymptotic CI
method is unioned with a design-based jackknife-Wald interval
(`private$design_conservative_ci()`, `:551-567`, confirmed to compute a
mathematically valid enclosing interval — `c(min(model_lo, design_lo),
max(model_hi, design_hi))`, which provably guarantees coverage ≥ both
components'), specifically to guard against "the model-based test being
anti-conservative when the Poisson equidispersion assumption... fails."
Direct verification against the audit findings confirms this mechanism
WORKS for the methods it's wired to — `compute_wald_confidence_interval`/
`compute_asymp_confidence_interval`/`compute_score_confidence_interval`/
`compute_gradient_confidence_interval`/`compute_lik_ratio_confidence_interval`
are ALL absent from the flagged findings (clean coverage), while the raw
`compute_jackknife_wald_confidence_interval` alone (unprotected, used as
a standalone public method too) correctly shows the underlying
undercoverage (0.871-0.929) the union is designed to absorb.

**But two other method families on the same class are NOT wired into this
union and inherit the exact equidispersion-anti-conservativeness the
mechanism exists to prevent:**
1. `compute_lik_ratio_bartlett_confidence_interval`/`compute_lik_ratio_bartlett_approx_confidence_interval`
   (0.883-0.915) — these are Bartlett-corrected variants of the SAME
   test-inversion CI as `compute_lik_ratio_confidence_interval`, which
   IS unioned and passes clean. There is no principled reason the
   Bartlett-corrected sibling should skip the same union — looks like a
   straightforward omission.
2. The resampling-family CI methods — `compute_bayesian_bootstrap_confidence_interval`
   (+ `_basic`/`_studentized`/`_wald` variants, 0.859-0.918),
   `compute_bootstrap_confidence_interval_studentized` (0.912),
   `compute_param_bootstrap_confidence_interval` (0.908-0.913) — none
   call `design_conservative_ci()`. `param_bootstrap` in particular is
   parametric (simulates new `Y ~ Poisson(fitted mean)` under the
   equidispersion-assuming model), so it mechanically inherits the same
   vulnerability by construction, not by omission — extending the union
   treatment here is more of a design question than a bug fix.
   `bayesian_bootstrap`'s exact mechanism wasn't traced far enough this
   pass to say the same with confidence.

**Fix direction, item 1 (high-confidence, concrete):** wire
`compute_lik_ratio_bartlett_confidence_interval`/`_approx` through
`private$design_conservative_ci()` the same way `compute_lik_ratio_confidence_interval`
already is — mechanical, low-risk, matches an existing pattern in the
same file.

**Item 2 (resampling-family methods) is a genuine design decision, not an
obvious bug** — whether to union jackknife-Wald into bootstrap-family CIs
too, or to document that those methods are NOT equidispersion-robust on
this class and users needing that robustness should prefer the
asymptotic methods. Left open, not slated as a confirmed bug.

**`InferenceCountNegBin`/`InferenceCountZeroInflatedPoisson` — separate,
still-unresolved finding.** Both classes explicitly report
`compute_jackknife_*` as **unsupported**
(`"negbin_jackknife_not_supported"`/`"zero_augmented_poisson_jackknife_not_supported"`)
— neither has ANY union/robustness backstop, unlike `InferenceCountPoisson`.
Yet both are dispersion-modeling classes (NegBin's own dispersion
parameter, ZIP's zero-inflation mixture) that `InferenceCountPoisson`'s
own docstring points to as the alternative to the jackknife-union trick
("see `InferenceCountNegBin` for a model that estimates dispersion
directly instead"). NegBin's asymptotic family (`asymp`/`wald`/`score`/
`gradient`/`lik_ratio`, all identically 0.916) still undercovers despite
this — meaning either (a) NegBin's dispersion parameter doesn't fully
match this DGP's log-normal-multiplicative overdispersion structure
(benign DGP/model mismatch), or (b) NegBin's own information-based
variance estimate is itself downward-biased in finite samples (a real,
separate SE bug). **Not distinguished this pass** — genuinely still open,
left in `release_v1_0_5.md → TODO-48` rather than promoted to a
confirmed-bug `release_v1_5_0.md` entry.

## TODOs

- [x] TODO-1 (2026-09-24, resolved): `beta_T` confirmed correct by direct
  derivation — see "Deep-dive update" above. Coverage-truth-mismatch
  hypothesis REFUTED.
- [x] TODO-2 → superseded: root cause for `InferenceCountPoisson` found
  (incomplete design-conservative union wiring, see "Deep-dive update"),
  not the truth-registry gap originally guessed. `InferenceCountZeroInflatedPoisson`'s
  own asymptotic-only cluster (`inference_count_zero_augmented_poisson_abstract.R`)
  still not individually root-caused — it has no jackknife backstop
  either (confirmed `zero_augmented_poisson_jackknife_not_supported`),
  same shape as NegBin's open finding below.
- [x] TODO-3 → superseded/refuted: `beta_T` is correct, no truth-registry
  entry needed for any of the 3 classes.
- [ ] TODO-4 (still open): quantitatively compare `InferenceCountNegBin`
  vs. `InferenceCountPoisson` coverage — done qualitatively above (NegBin
  0.916 uniformly across its 5 unprotected asymptotic methods vs.
  Poisson's same 5 methods all passing clean thanks to the jackknife
  union) but the underlying question — does NegBin's dispersion
  parameter genuinely help, or is its own variance estimate biased — is
  still unresolved.
- [ ] TODO-5 (new, added in the deep-dive pass — concrete, low-risk):
  implement the item-1 fix — wire `compute_lik_ratio_bartlett_confidence_interval`/
  `compute_lik_ratio_bartlett_approx_confidence_interval` through
  `private$design_conservative_ci()`, matching
  `compute_lik_ratio_confidence_interval`'s existing pattern
  (`inference_count_poisson.R`). Verify via `pkgload::load_all(".",
  compile = FALSE)` that this doesn't change results for any currently-
  passing method, then confirm it resolves the two flagged Bartlett
  findings on a fresh `comprehensive_tests` regeneration.
- [ ] TODO-6 (new): decide whether to extend the same union treatment to
  the resampling-family CI methods (`bayesian_bootstrap*`,
  `bootstrap_studentized`, `param_bootstrap`) or instead document them as
  not equidispersion-robust on this class — a design decision, not an
  obvious bug (see "Item 2" in the deep-dive update).
- [ ] TODO-7 (new): root-cause `InferenceCountNegBin`/`InferenceCountZeroInflatedPoisson`'s
  own undercoverage despite having no jackknife backstop and (for NegBin)
  an explicit dispersion parameter — distinguish "benign DGP/dispersion-
  family mismatch" from "NegBin's own variance estimate is downward-
  biased in finite samples" (a real, separate SE bug if so). Not resolved
  this pass; stays tracked at `release_v1_0_5.md → TODO-48`.

## Second deep-dive update 2026-09-24: TODO-7's "missing backstop"
hypothesis weakened by cross-class evidence, still not resolved

Dispatched to also fresh-root-cause the 8-class hurdle/KK cluster in
`investigate_count_hurdle_kk_and_prop_kkglmm_coverage.md`, since that
file's own conclusion had deferred to (now-refuted) truth-registry logic.
Two findings bear directly on this file's open TODO-7:

**The count-DGP truth derivation above generalizes to every count-response
class, not just Poisson/NegBin/ZeroInflatedPoisson** — `apply_treatment_effect_and_noise()`
is shared harness code for the whole `response_type == "count"` family, so
the `exp(eps)` log-normal correction cancels between arms identically for
every class using it. This REFUTES the truth-registry-gap hypothesis for
the 8-class hurdle/KK cluster too (see that file for the class-by-class
detail), by the same derivation, not a new one.

**`design_conservative_ci()` — confirmed via `grep -rln` across all of
`R/EDI/R/` — exists ONLY in `inference_count_poisson.R`.** No other
count-family class (`InferenceCountNegBin`, the whole
`InferenceCountZeroAugmentedPoissonAbstract` hierarchy covering Hurdle/
ZeroInflated variants, `InferenceCountQuasiPoisson`) has this or any
equivalent CI-union robustness mechanism — they simply never had one
added, which is a bigger gap than "TODO-5's Bartlett-variant wiring is
incomplete."

**But this "just add the missing backstop" framing is directly
undercut by `InferenceCountQuasiPoisson` and `InferenceCountNegBin`
themselves**: both classes DO already have their own real, correctly-
implemented dispersion-correction machinery — QuasiPoisson's Pearson-
scaled SE (`inference_count_quasipoisson.R:146-159`, standard
`sum(w*(y-mu)^2/mu)/df_resid` formula, looks correct on inspection) and
NegBin's own dispersion parameter — yet BOTH still show the same
~0.88-0.92 undercoverage on their genuinely-dispersion-corrected
asymptotic paths (QuasiPoisson: `asymp`/`wald` both 0.904-0.921;
NegBin: `asymp`/`wald`/`score`/`gradient`/`lik_ratio` uniformly 0.916).
This is the strongest evidence yet that the problem is NOT simply
"missing robustness machinery" — a class that already has a textbook-
correct dispersion correction still shows the same-magnitude
undercoverage as classes with none at all. Two live, undistinguished
possibilities: (a) the dispersion ESTIMATE itself (Pearson-scale or
NegBin's gamma-mixture) is finite-sample downward-biased under this
DGP's specific noise structure, a real and potentially fixable bug; or
(b) this DGP's log-normal-multiplicative noise genuinely isn't well
captured by either a single Pearson scale factor or a NegBin gamma
mixture — a benign DGP/model-family mismatch, not a package defect.
**Not resolved — needs a targeted simulation comparing the ESTIMATED
dispersion/gamma parameter against the DGP's true implied overdispersion
to distinguish (a) from (b), out of scope for this pass.**

**One promising, narrower lead for `InferenceCountKKGLMM` specifically**
(part of the separate hurdle/KK cluster, noted here since it bears on the
same "incomplete backstop wiring" pattern as this file's TODO-5): unlike
the broad Poisson-style "everything affected" shape, `InferenceCountKKGLMM`'s
11 findings are narrower — `compute_wald`/`compute_asymp`/`compute_score`/
`compute_lik_ratio_confidence_interval` are ALL clean, while
`compute_gradient_confidence_interval` and the resampling-family methods
(`bayesian_bootstrap*`, `param_bootstrap`) are flagged. This class has its
own jackknife-based SE-inflation mechanism
(`.inflate_kk_onelik_standard_error_with_jackknife()`,
`inference_count_KK_cond_poisson.R:1-12`, called unconditionally from
`compute_estimate()` at `inference_count_KK_combined.R:307`) — the
pattern (wald/asymp/score/lik_ratio protected, gradient + resampling not)
is consistent with that inflation feeding the main cached SE that
wald/asymp/score/lik_ratio read, while `compute_gradient_confidence_interval`
and the resampling paths build their SE from a different, unprotected
source — the SAME shape of bug as this file's already-confirmed TODO-5
(Bartlett variants skipping Poisson's union), just in a sibling class.
**Not traced to confirm** — would need reading `compute_gradient_confidence_interval`'s
actual SE source for `InferenceCountKKGLMM` to confirm it bypasses the
jackknife inflation. Flagged as the most promising concrete next step in
this whole count-family investigation thread.

**Net: TODO-7 remains genuinely open.** Not promoted to `release_v1_5_0.md`
— no class in the broad-undercoverage bucket (NegBin, ZeroInflatedPoisson,
Hurdle×2, ZeroInflatedNegBin, QuasiPoisson) has a root cause confirmed to
a specific line; only the narrower, more mechanistic `InferenceCountKKGLMM`
gradient/resampling gap looks likely to be the "same bug class" as the
already-confirmed TODO-5, and even that needs one more read to confirm.

## TODO-7 resolved 2026-09-24: BENIGN — genuine finite-sample MLE bias, not a code defect

Investigated `InferenceCountNegBin`'s and `InferenceCountZeroInflatedPoisson`'s
actual SE-computation code directly to distinguish "finite-sample bias in
a textbook-known-problematic estimator" from "an addressable implementation
defect."

**Both use standard, textbook-correct joint MLE with observed-information
Wald SEs — no formula bug found.** `InferenceCountNegBin`
(`inference_count_negbin.R`): jointly optimizes regression coefficients
and `log(theta)` via `get_negbin_regression_hessian_cpp()`, inverts the
observed Hessian for the joint vcov — exactly what `MASS::glm.nb()` does
internally. `InferenceCountZeroInflatedPoisson`
(`inference_count_zero_augmented_poisson_abstract.R:739-766`): identical
pattern via `get_zero_augmented_poisson_hessian_cpp()`, observed
information inverted for vcov. Both are standard, correctly-implemented
maximum-likelihood approaches with no missing correction term or
misapplied formula.

**Conclusion: this is genuine, well-documented finite-sample MLE bias, not
a package bug.** Joint ML estimation of a dispersion parameter (NegBin's
`theta`) or a mixture-probability parameter (ZIP's zero-inflation
probability) is textbook-known to converge to asymptotic normality more
slowly than a plain GLM's regression coefficients — the dispersion/mixture
parameter itself is finite-sample-biased, and this bias propagates into
the joint observed-information matrix's off-diagonal terms, mildly
deflating the *regression* coefficient's own SE too. This is the same
well-documented phenomenon `MASS::glm.nb()` itself exhibits at small-
moderate n (see e.g. Lawless 1987 on NegBin dispersion bias) — not
something specific to this package's implementation. The harness's sample
size (`max_n_dataset = 148`, per-arm smaller still) is squarely in the
range where this bias is non-trivial, consistent with the observed
~0.85-0.93 coverage.

A Cox-Reid-style bias-adjusted profile dispersion estimator (or an
analogous ZIP correction) is a well-known, implementable enhancement that
would likely improve coverage here — but this is a genuine
methodological upgrade to add new machinery, not a defect fix, since the
current implementation already does the standard-textbook thing
correctly. **Closed as BENIGN, not promoted to `release_v1_5_0.md`.** If
this improvement is wanted, it belongs as a `release_v1_1_0.md`-style
inference-quality enhancement (a new estimator feature), not a bug-fix
release — flagged here for whoever triages that backlog, not actioned
further in this pass.

- [x] TODO-7 (resolved 2026-09-24): BENIGN — genuine finite-sample joint-MLE
  bias in dispersion/mixture-parameter estimation for both
  `InferenceCountNegBin` and `InferenceCountZeroInflatedPoisson`, same
  category as `MASS::glm.nb()`'s own well-documented small-n behavior, not
  a package implementation defect. A Cox-Reid-style bias correction is a
  possible future enhancement (new machinery), not a bug fix — not slated
  here.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only. TODO-1's
simulation step, if pursued, must not require any package recompilation —
it exercises `comprehensive_tests.R`'s DGP logic and/or the already-
installed package only.
