# Investigate: Count Hurdle/Zero-Inflated/KK Cluster + `InferencePropKKGLMM` `low_coverage` Findings

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's newly-surfaced `low_coverage`
> backlog (`audit_comprehensive_results.R`, first real run against fresh
> data). **Neither cluster's root cause is confirmed to a specific
> line — medium/low confidence throughout.** `TODO-28` (`cached_design_matrix`
> staleness) is already definitively ruled out for `InferenceCountKKGLMM`
> and `InferencePropKKGLMM` by `bootstrap_worker_stale_design_matrix.md`
> (both reach `create_design_matrix()` in their call chain but never the
> stale branch, since neither overrides `supports_reusable_bootstrap_worker()`).

## Group 1: count-family hurdle/zero-inflated/KK cluster (63 findings)

`InferenceCountHurdlePoisson` (12), `InferenceCountKKGLMM` (11),
`InferenceCountHurdleNegBin` (10), `InferenceCountZeroInflatedNegBin` (9),
`InferenceCountQuasiPoisson` (8), `InferenceCountKKHurdlePoissonOneLik` (6),
`InferenceCountKKCondPoissonOneLik` (5), `InferenceCountPoissonKKGEE` (2).

### Pattern

Uniform, broad UNDERcoverage across all 8 classes: 0.80-0.92 vs. 0.95
target (one exception: `InferenceCountQuasiPoisson`'s
`compute_subsampling_confidence_interval` at `~.` shows perfect 1.000
OVER-coverage, 164 rows — an isolated outlier in the opposite direction,
not investigated further here). Both asymptotic (`asymp`/`wald`/`score`/
`gradient`/`lik_ratio`) AND resampling-family (`bayesian_bootstrap*`,
`param_bootstrap`, `subsampling`, `m_out_of_n_bootstrap`) methods are
affected simultaneously within each class, at similar magnitude.

### Truth-registry gap — REFUTED for all 8, same as its sibling cluster (update 2026-09-24)

Checked `comprehensive_tests.R`'s `COVERAGE_CLOSED_FORM` and
`COVERAGE_MC_SPEC` registries directly (`grep`, both list bodies read in
full): none of the 8 classes in this cluster appear in either table, so
coverage checking does fall back to raw `beta_T` as ground truth for all
of them. **However, `investigate_count_glm_family_coverage.md`'s
follow-up deep-dive has since REFUTED the truth-registry-mismatch
hypothesis for its own cluster via direct DGP derivation** (`beta_T` is
confirmed the mathematically correct truth for the whole count-response
family, since `apply_treatment_effect_and_noise()`'s `exp(eps)`
log-normal correction cancels identically between arms for every class
using that shared harness DGP function — not a per-class computation, so
the derivation applies unchanged here). **This file's original deferred
conclusion — "very likely the same underlying harness gap" — is now
WRONG and is corrected here: it is not a truth-registry gap for any of
these 8 classes either.** The real, undercovering cells need independent
root-causing; see `investigate_count_glm_family_coverage.md`'s "Second
deep-dive update" section for what's known so far, since the
investigation converged there rather than here.

### Inheritance is NOT uniform across this cluster — argues against a
### single shared code-level bug

Checked directly: `InferenceCountHurdlePoisson` and
`InferenceCountZeroInflatedNegBin` both inherit
`InferenceCountZeroAugmentedPoissonAbstract`
(`inference_count_hurdle.R:68`, `inference_count_zero_inflated.R:69`/`292`).
**`InferenceCountHurdleNegBin` inherits `Inference` directly**
(`inference_count_hurdle.R:273`) — architecturally independent of the
shared abstract despite the similar name and near-identical coverage
numbers to its "sibling." `InferenceCountQuasiPoisson` also inherits
`Inference` directly. Since classes with genuinely different
implementations show the same coverage pattern at similar magnitude, a
single class-hierarchy-level SE bug is a weaker explanation than a
harness-level truth-registry gap, which would naturally produce a
uniform-looking symptom regardless of each class's actual (different)
estimator code. **Not proven either way** — this is circumstantial
evidence favoring the harness-gap hypothesis, not a derivation.

### `InferenceCountKKGLMM`/`InferencePropKKGLMM`-adjacent note

`InferenceCountKKGLMM` and `InferenceCountKKHurdlePoissonOneLik`/
`InferenceCountKKCondPoissonOneLik`/`InferenceCountPoissonKKGEE` are all
"KK"-prefixed (matched-pair-aware) variants layered on top of the same
underlying count models — not investigated individually beyond the
registry check above; likely share whatever the non-KK siblings'
resolution turns out to be, but not confirmed.

## Group 2: `InferencePropKKGLMM` (13 findings)

### Pattern — two distinct signals, not one

1. **Broad OVER-coverage** (1.000, i.e. perfect, over 8 of the 13 cells:
   `asymp`, `lik_ratio`, `score`, `wald`, `gradient`, `param_bootstrap`
   confidence intervals, both `~1` and (blank) formula) — co-occurring
   with a `biased_estimate` finding (`compute_estimate`: mean bias
   +0.0305 to +0.0645, ACAT p=7-9e-03). A positive point-estimate bias
   combined with over-wide (conservative) CIs can produce apparent
   over-coverage without the CI width itself being wrong — **not
   confirmed to be a distinct bug from the bias itself**; the bias may be
   primary and the coverage numbers downstream of it.
2. **One sharp outlier in the OPPOSITE direction**:
   `compute_jackknife_wald_confidence_interval` at `~1` shows **UNDER**-
   coverage at 0.779 (136 rows, p=5.94e-12) — a much larger, more
   confident signal than the broad over-coverage cluster, and the more
   likely genuine bug of the two.

### Truth registry: NOT a gap here

Unlike Group 1, `InferencePropKKGLMM` **IS** in `COVERAGE_MC_SPEC`
(`comprehensive_tests.R:~3308`, `mc_n = 3000L`, `design =
DesignFixedBinaryMatch`) — coverage is checked against an empirically
MC-refit truth, not a raw-`beta_T` fallback. The truth-registry-gap
explanation used for Group 1 does **not** apply here; this class's
coverage findings need a genuine estimator/SE explanation.

### `jackknife_wald` outlier — RESOLVED 2026-09-24: same bug as `release_v1_5_0.md → TODO-5`, not a separate degenerate-fold issue

Checked directly whether `InferencePropKKGLMM` customizes the jackknife
leave-one-out fold logic for its matched-pair/clustered structure: it
(via `inference_proportion_KK_combined.R` and its
`InferenceAbstractKKCondLogitGLMM` base) declares
`resolve_jackknife_unit`/`jackknife_block_size_gt_one_unsupported`/
`mark_jackknife_nonestimable_if_block_unsupported` in its component
"overrides" list, but grepping for actual `resolve_jackknife_unit =
function` definitions across `R/EDI/R/` finds them ONLY in the generic
base (`inference_all_abstract_jackknife.R`) — these names are *kept from*
the generic implementation during component composition, not given
class-specific bodies. The generic `resolve_jackknife_unit()` already
handles matched-pair designs design-agnostically (`private$is_KK` →
`"matched_set"` unit, `inference_all_abstract_jackknife.R:170-185`) —
there is no class-specific fold code to contain a bug.
`compute_jackknife_summary()` and
`compute_jackknife_wald_confidence_interval()` are both fully generic too
(untouched by any override). **`InferencePropKKGLMM` therefore inherits
the already-confirmed `release_v1_5_0.md → TODO-5` CI-centering bug
unmodified** (`R/EDI/R/inference_all_abstract_jackknife.R:118-145`,
CI centers on the raw `theta_hat` instead of the bias-corrected `theta_j`;
loose `abs(bias_j) > 2*se_j` acceptance guard lets substantial bias
through) — same mechanism as `InferenceIncidProbitRegr`'s outlier, just a
larger observed coverage drop (0.779 vs. 0.926), plausibly because this
class's matched-pair conditional-logit-style estimator has larger
finite-sample `bias_j`. **Third confirmed-affected class for `TODO-5`
(see its linked plan file's new cross-class section) — no new,
independent bug here, and no separate `release_v1_5_0.md` entry needed.**
The `fix_kk_weibull_marginal_jackknife_outliers.md`-style degenerate-fold
hypothesis is now ruled out for this class specifically.

## TODOs

- [x] TODO-1 (2026-09-24, resolved): truth-registry-mismatch hypothesis
  REFUTED for all 8 classes, by the same DGP derivation as
  `investigate_count_glm_family_coverage.md` — see the corrected section
  above. Do not re-open without new evidence.
- [x] TODO-2 → moot: no truth-registry fix needed (hypothesis refuted).
  Root cause for Group 1's broad undercoverage is now tracked entirely in
  `investigate_count_glm_family_coverage.md`'s "Second deep-dive update"
  (open: whether NegBin/QuasiPoisson-style genuine dispersion correction
  is itself finite-sample-biased, vs. a benign DGP/model mismatch), plus
  a promising narrower lead specific to `InferenceCountKKGLMM`
  (gradient/resampling-family methods possibly bypassing its own
  jackknife-inflation backstop — same shape as `InferenceCountPoisson`'s
  confirmed TODO-5 gap, not yet traced to confirm).
- [x] TODO-3 (2026-09-24, done): root-caused — see "RESOLVED" section
  above. `InferencePropKKGLMM` uses fully generic jackknife machinery (no
  class-specific fold logic exists), so its outlier is the SAME bug as
  `release_v1_5_0.md → TODO-5`, not a separate degenerate-fold issue. No
  further action needed here beyond `TODO-5`'s own fix.
- [x] TODO-4 (2026-09-24, investigated, still open — no bug confirmed):
  `InferencePropKKGLMM`'s `compute_estimate()` (`InferenceAbstractKKCondLogitGLMM$compute_estimate`,
  `inference_incidence_KK_cond_logit_glmm_abstract.R:72-74`) reads
  `private$cached_values$beta_hat_T` directly with **no sign flip or
  transformation anywhere in the path** — ruled out a Cloglog-style
  (`project_ordinal_param_bootstrap_sign_bug`) public/native sign
  mismatch; this class has no such convention to get wrong.
  `compute_estimate_with_bootstrap_weights()` similarly reads
  `glmmTMB::fixef(mod)$cond[["w"]]` directly, no negation. Re-queried the
  raw `comprehensive_tests_results_nc_1_proportion.csv` directly
  (stratifying by the `model_formula=~1`/`~.` tag baked into
  `inference_class`, which the CSV's own `beta_T`/`result_1` columns
  don't otherwise expose): confirmed the bias is real and **flips sign
  by formula** — `+0.0427` (`~1`, n=62 cells) vs. `-0.0307` (`~.`, n=63
  cells), both nonzero (`sd≈0.15-0.19`). This sign flip is the most
  notable feature — ordinary finite-sample bias in a joint conditional-
  logit+GLMM MLE would not obviously be expected to reverse sign with
  covariate adjustment alone, which argues weakly against pure benign
  finite-sample noise, though it doesn't rule it out either (adding
  covariates changes which pairs are discordant vs. concordant under the
  design and can plausibly shift a compound estimator's finite-sample
  bias direction). **Could not test the planned n-scaling diagnostic**:
  `comprehensive_tests.R` runs every case at a single fixed
  `max_n_dataset = 148` — there is no varying-`n` data in this harness to
  check whether bias shrinks with `n` (the standard signature that would
  distinguish ordinary finite-sample bias from a structural defect).
  This is a real methodological gap in the harness for THIS kind of
  diagnostic generally, not specific to this class — worth flagging
  separately if bias-magnitude-vs-n questions come up again elsewhere in
  this audit. **Conclusion: real, reproducible, sign-flipping bias;
  origin genuinely undetermined between "ordinary compound-estimator
  finite-sample bias" and "a real defect somewhere in the discordant/
  concordant pair split or GLMM design-matrix construction that
  interacts with covariate adjustment."** Not confirmed enough to promote
  to `release_v1_5_0.md` — would need either a synthetic-`n` simulation
  (bypassing the harness's fixed 148) or a closer read of
  `fast_clogit_plus_glmm_cpp`'s discordant/concordant split logic to
  settle definitively.
- [ ] TODO-5: `InferenceCountQuasiPoisson`'s isolated
  `compute_subsampling_confidence_interval ~. ` perfect-1.000
  over-coverage outlier (164 rows) — not investigated, may be unrelated
  to the broad Group 1 pattern.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
