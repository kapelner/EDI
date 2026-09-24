# Investigation: `InferenceIncidKKModifiedPoisson` Chronic Under-Rejection / 100% CI Coverage — SE-Quality Hypothesis (Symptom Confirmed Real 2026-09-24, Magnitude Still Unpinned)

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-19`. Added 2026-09-23, same audit-triage wave as
> TODO-17/TODO-18. **This is an open investigation, not a confirmed bug with
> a fix plan.** Status as of Round 3 (2026-09-24): the original ~4×
> SE-overestimation NUMBER was refuted, but a faithful reproduction confirms
> the underlying SYMPTOM (0% power, 100% coverage) is real, and an
> independent coverage-audit check corroborates it from a second angle. What
> remains open is the MAGNITUDE of SE overestimation (modest ~1.3×, possibly
> just sampling noise at the rep counts tried so far) and whether that
> magnitude is a genuine code defect or an inherent small-effect-size
> property of this benchmark scenario. Do not treat anything below as a
> diagnosed root cause until the "Next steps" section is completed.

## The finding that started this

Historical `comprehensive_tests` CSV rows flagged `bad_type1_error` for
`InferenceIncidKKModifiedPoisson` at `model_formula=~1`: reject-rate **0.000**
across MULTIPLE unrelated test-statistic families simultaneously (Wald,
score, gradient, likelihood-ratio, Bartlett all zero-reject at the same
cell). Zero-across-every-family is the interesting/unusual part — a bug in
one test statistic's formula wouldn't do that; something shared by all of
them (most plausibly the variance estimate they all consume) would.

## Hypothesis 1 (original) — REFUTED

**Claim**: a structurally non-estimable/degenerate cell, similar in shape to
`InferenceAllSimpleWilcox`'s TODO-17 finding (see
`simple_wilcox_hl_degenerate_pval_boundary.md`).

**Refuted directly**: `compute_estimate()` for the exact flagged cell
(n=172, beta_T=0) shows 146 distinct values ranging -0.37 to 0.52, only
4.65% exactly 0 — a normally-varying point estimate, not a degenerate one.
Not TODO-17's failure mode.

## Hypothesis 2 — over-estimated SE — REFUTED (checked 2026-09-23)

**Claim**: Wald CI width for the flagged cell had median 0.82 (half-width
≈0.41) while the point estimate's own empirical IQR was only (-0.11, 0.12) —
roughly 4x wider than the estimate's actual spread. If every test family
consumes the same over-estimated variance, all would under-reject together,
which matches the "all five families zero-reject" observation.

**Checked against the empirical SD 2026-09-23 (refuted as originally
stated, medium confidence — approximate fixture, not an exact harness
replay)**: 40 true-null reps on a hand-built fixture approximating the
flagged cell (`model_formula=~1`, `DesignSeqOneByOneKK21stepwise`, n=148):
empirical SD of `beta_hat_T` = 0.221, mean implied SE from the asymptotic CI
= 0.272 — a 1.23× ratio, mildly conservative, nowhere near the ~4× estimated
from the historical CSV's IQR-vs-CI-width comparison. Wald reject rate =
2.5% (1/40) — mildly conservative vs. nominal 5%, not the dramatic "0.000
across every test family" the original finding reported. The dramatic
pattern did not reproduce.

Two live possibilities, neither resolved:
1. The hand-built fixture isn't a faithful enough replay of
   `comprehensive_tests.R`'s exact data-generating process (baseline
   probability, per-subject noise).
2. The original historical-CSV comparison (IQR vs. CI width) pooled rows
   across conditions in a way that wasn't a clean apples-to-apples
   comparison — the same pooling risk flagged elsewhere in this session's
   own audit-tooling work.

## Broadened context 2026-09-23 — cross-class SE-quality lead (separately motivated, not cross-confirmed)

A second, independent investigation (into `type="studentized"`/
`"symmetric-percentile-t"` randomization-bootstrap p-values, which also
showed wildly class-dependent miscalibration direction/severity across
`InferenceOrdinalGCompMeanDiff`, `InferenceIncidKKCondLogitGLMMOneLik`,
`InferenceIncidKKGEE`, `InferenceContinQuantileRegr` — same triage wave)
traced the shared dispatch/pivot code
(`compute_rand_bootstrap_two_sided_pval()`,
`inference_all_abstract_rand_bootstrap.R:471-505`, pivot formula at
`:1026-1038`) and found it **correct** — the observed and every null-draw
pivot read the identical `cached_values$s_beta_hat_T` field, no cross-
estimator mismatch, no shared-code bug. That's evidence FOR a per-class
SE-estimator-quality explanation (as opposed to a single shared bug)
*for the studentized-pivot pattern*, since a class whose asymptotic/plug-in
`s_beta_hat_T` is a poor finite-sample approximation would degrade every
test family that consumes it (Wald/score/gradient/LR/Bartlett AND the
studentized-bootstrap pivot) simultaneously through that one shared field —
over-estimated SE → conservative/under-reject, under-estimated SE →
anti-conservative/over-reject, both directions genuinely observed across
the four classes checked there.

**Tension, explicitly noted**: that "broadened" reasoning partly leaned on
this investigation's original ~4× SE-overestimation number for
`InferenceIncidKKModifiedPoisson`, which the direct empirical-SD check above
did NOT confirm (found 1.23×, not ~4×). The studentized-BRT-pivot code trace
is still valid on its own (the shared dispatch/pivot code is clean), so
"per-class SE-estimator quality, not shared-code bug" remains the
best-supported explanation for the studentized-pivot miscalibration
specifically — but it should no longer be read as cross-confirmed by this
investigation's own original finding, since that finding didn't hold up.
Treat the two threads (studentized-pivot class-dependence;
`InferenceIncidKKModifiedPoisson`'s Wald-family zero-rejection) as
**separately-motivated, not mutually reinforcing**, until at least one is
confirmed with a faithful harness replay.

## Round 3 (2026-09-24) — a faithful harness replay, plus a NEW corroborating signal from the coverage audit

**A faithful reproduction was built this time** (pima dataset via the
harness's own `MASS::Pima.tr2` loading, `DesignSeqOneByOneKK21stepwise`,
n=148, `apply_treatment_effect_and_noise()`'s exact mechanism
`p_t = plogis(qlogis(p_base) + bt + eps)`, `SD_NOISE=0.1` — matching
`comprehensive_tests.R`'s actual DGP, not a hand-approximation this time),
40 reps at `beta_T=0.5` via `pkgload`-loaded, already-installed EDI (no
compile):

- `compute_score_two_sided_pval()` reject rate: **0/40 (0%)** — matches
  the historical finding exactly.
- Coverage against the MC-derived truth (0.086, confirmed the correct
  log-risk-ratio-scale target, not raw `beta_T=0.5`): **40/40 (100%)** —
  also matches exactly.
- Empirical SD of `beta_hat_T`: **0.210**. Mean reported SE (from
  `compute_score_confidence_interval()`): **0.279**. Ratio: **1.33×** —
  real but modest, not "grossly" inflated, and within the range plausibly
  explained by ordinary sampling noise in an SD estimate from only 40 reps
  (SE of the SD estimate itself ≈ 0.024 at this n — a faithful DGP finally
  reproduced the *symptom* but the *magnitude* of SE inflation remains
  genuinely ambiguous at this rep count).

**Revised interpretation**: the 0%-power/100%-coverage symptom is now
confirmed real and reproducible with a faithful fixture (this alone closes
possibility 1 from Round 2's open list — the earlier non-reproduction WAS
a fixture-fidelity problem, not evidence the effect isn't real). But the
magnitude question is still open: the MC truth (0.086) is small relative
to this design's actual achievable precision (SD ≈ 0.21-0.28) at n=148 —
effect size ≈ 0.086/0.25 ≈ 0.34 SD-units. A MODEST (1.2-1.4×), not
catastrophic, SE overestimate combined with this small a true effect can
land at exactly this symptom without any single dramatic bug — this may be
a genuinely underpowered benchmark scenario for this class/design/n
combination at least as much as a code defect. 40 reps cannot distinguish
"true 1.33×" from "sampling noise around 1.0×" with confidence.

**NEW, independent corroborating evidence from the coverage audit
(2026-09-24, different check entirely)**: the same class shows exactly
100% CI coverage across SEVEN-PLUS unrelated method families
(`compute_score_confidence_interval`, `compute_lik_ratio_confidence_interval`,
`compute_gradient_confidence_interval`, `compute_m_out_of_n_bootstrap_confidence_interval`
×2 formulas, `compute_subsampling_confidence_interval` ×2,
`compute_lik_ratio_bootstrap_confidence_interval` ×2) in the historical
CSV — this is the SAME symptom (over-wide CI / chronic non-rejection),
found completely independently via the two-sided exact-binomial coverage
test rather than the original Type-I-error framing. Two different checks,
built independently, both landing on the same class with the same
"everything is too wide" signature is meaningfully stronger evidence the
symptom is real than either check alone — even though, per Round 3's own
reproduction, the *magnitude* still isn't pinned down precisely.

## Next steps (updated 2026-09-24)

- [ ] Re-run Round 3's faithful fixture with ≥200 reps (not 40) to get a
  statistically meaningful empirical-SD-vs-SE ratio — this is now the
  single highest-value next step, since fixture fidelity is no longer the
  blocker, only rep count is.
- [ ] If ≥200 reps confirms a ratio meaningfully >1 (not just noise around
  1.0), THEN proceed to `build_design_matrix()`/
  `reduce_design_matrix_preserving_treatment()` (not yet read by any round
  of this investigation) as the next candidate location for a code-level
  cause — Round 2 cleared the sandwich formula, cluster ID assignment, and
  coverage-truth target, but never checked the design-matrix-building path
  upstream of those.
- [ ] If ≥200 reps confirms the ratio is genuinely ~1.0-1.3× (modest), this
  may not be a "bug" in the defect sense at all — write up as a documented
  known-limitation (small effect size relative to this design's achievable
  precision at n=148), not a fix plan, and close this investigation as
  resolved-not-a-defect.
- [ ] Reproduce using `comprehensive_tests.R`'s actual DGP call path (not a
  hand-built approximation) for the exact flagged cell
  (`InferenceIncidKKModifiedPoisson`, `model_formula=~1`), with enough true-
  null reps (≥200) to get a stable empirical-SD-vs-implied-SE ratio.
- [ ] Alternatively, re-pull the original historical finding fresh from a
  larger CSV sample and check whether the ~4× IQR-vs-CI-width gap was an
  artifact of pooling rows across conditions (the specific risk flagged
  above) before concluding anything about SE quality for this class.
- [ ] If a real SE-quality problem is confirmed for this class specifically,
  identify which variance-estimator code path it uses
  (`InferenceIncidKKModifiedPoisson`'s own `shared()`/variance computation)
  and check whether it's a per-class formula bug or a genuine finite-sample
  asymptotic-approximation weakness (the latter might not have a "fix" in
  the bug sense — could end up documented as a known limitation instead,
  same caveat as TODO-20's BRT-tie lead).
- [ ] Independently, if picked up: extend the four-class studentized-pivot
  cross-class check (`InferenceOrdinalGCompMeanDiff`,
  `InferenceIncidKKCondLogitGLMMOneLik`, `InferenceIncidKKGEE`,
  `InferenceContinQuantileRegr`) with an empirical-SD-vs-implied-SE ratio
  measurement per class, the same way this investigation did for
  `InferenceIncidKKModifiedPoisson`, to actually test the "per-class
  SE-estimator quality" hypothesis on classes it wasn't refuted on yet.
- [ ] Only once at least one of the above confirms a concrete, fixable
  mechanism should this file be replaced/upgraded to a normal `# Fix:` plan
  with its own `## TODOs` fix checklist.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`). Any reproduction work
must state explicitly whether it used the real `comprehensive_tests.R` DGP
or an approximation — the approximation-vs-real distinction already caused
one non-reproduction in this investigation and must not be glossed over
again.
