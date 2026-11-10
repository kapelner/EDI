# Fix: KK Matched-Pair Bootstrap Weight Collapsing Dampens Resampling Variance — Undercoverage in the "OneLik" Cluster

> **Depends on:** none. Found 2026-09-24, investigating `low_coverage`
> findings for `InferenceContinKKOLSOneLik` (10 findings),
> `InferenceContinKKRobustRegrOneLik` (12), `InferenceContinKKQuantileRegrOneLik`
> (11), and `InferenceContinKKGLMM` (3) from a fresh
> `audit_comprehensive_results.R` run. **High confidence for the OneLik
> trio — confirmed by direct code reading and a rigorous statistical
> argument, not yet empirically reproduced.** `InferenceContinKKGLMM` is
> architecturally distinct and NOT explained by this mechanism — separate,
> lower-priority, unresolved.

## The pattern (from the audit CSV)

All 4 classes show broad, mostly UNDER-coverage (0.76-0.91 vs. 0.95
target) across nearly every resampling-family `function_run`
(`compute_bayesian_bootstrap_confidence_interval*`,
`compute_bootstrap_confidence_interval*`,
`compute_param_bootstrap_confidence_interval`,
`compute_subsampling_confidence_interval`,
`compute_jackknife_wald_confidence_interval`), both `~1` and `~.`
formulas. A few OVER-coverage outliers exist (`InferenceContinKKOLSOneLik
~1 compute_jackknife_wald_confidence_interval` at 0.973,
`InferenceContinKKQuantileRegrOneLik ~1 compute_rand_bootstrap_confidence_interval*`
at 0.99-1.00 — the latter is a permutation-based method, not
weight-based, and likely unrelated to this mechanism).

`TODO-28` (`bootstrap_worker_stale_design_matrix.md`) already ruled this
cluster in/out inconsistently across forks: `InferenceContinKKOLSOneLik`/
`InferenceContinKKRobustRegrOneLik` are REFUTED (don't call
`create_design_matrix()`); `InferenceContinKKGLMM` is RULED OUT (doesn't
reach the reused-worker path); `InferenceContinKKQuantileRegrOneLik` was
"unresolved." None of that explains the observed undercoverage — this
plan finds an independent mechanism for 3 of the 4.

## The bug (OneLik trio: OLS, RobustRegr, QuantileRegr)

All three route their weighted refit through the shared helper
`kk_pair_and_reservoir_bootstrap_weights()`
(`R/EDI/R/globals.R:245-269`), confirmed via direct call sites:
`inference_continuous_KK_ols_one_lik.R:459` (`fit_weighted_combined`),
`inference_continuous_KK_robust_regr_one_lik.R` (same pattern), and
`inference_all_KK_quantile_regr_one_lik_abstract.R:278`
(`compute_weighted_combined_estimate`).

This helper takes per-ROW bootstrap weights (`row_weights`, one per
subject, expanded from `subject_or_block_weights` via
`expand_subject_or_block_weights_to_row_weights()`,
`inference_all_abstract_bayesian_bootstrap.R:591-600`) and, for every KK
matched pair `pid` (identified by `private$m`, the pair-id vector from
the class's own post-hoc greedy/nearest-neighbor matching — **independent
of the design's own randomization/blocking units**), computes:

```r
pair_weights[pid] = mean(row_weights[m_vec == pid], na.rm = TRUE)
```

— i.e. it **averages the two matched subjects' independently-drawn
per-subject bootstrap weights** into a single weight for the pair's
difference statistic (`y_matched_diffs`).

**Why this dampens resampling variance:** for the harness's non-blocking
designs (Bernoulli, iBCRD, Efron, KK14/KK21/KK21stepwise, SPBR,
PocockSimon, Urn — the majority of `TESTED_DESIGNS`), the bootstrap-weight
generator's resampling unit (`design_obj$get_block_ids()`,
`inference_all_abstract_bayesian_bootstrap.R:542`) is the *subject*, not
the KK class's own post-hoc matched pair (that pairing is constructed
independently, after randomization, by the inference class's own
`compute_basic_match_data()` greedy-matching step — it has no relationship
to the design's block structure for these design types). So for a matched
pair `(subject_i, subject_j)`, `row_weights[i]` and `row_weights[j]` are
two **independent** Dirichlet/multinomial-type draws.

`Var(mean(w_i, w_j)) = Var(w)/2` for two i.i.d. draws — averaging the
pair's two independent weights **halves the effective per-pair weight
variance** relative to what a bootstrap that correctly treated the pair
as the resampling unit (drawing one Dirichlet weight per pair) would
produce. Since the whole point of a weighted-bootstrap CI is to have the
between-replicate spread of the *weighted* statistic reproduce the true
sampling variability, systematically shrinking the pair weights' variance
systematically shrinks the resulting SE estimate — directly predicting
the observed broad UNDERCOVERAGE (SE too small → CI too narrow → true
value falls outside it more than 5% of the time).

This is a genuine statistical/code defect, not a benign approximation:
the correct unit to resample for a matched-pair statistic is the pair
itself (one weight draw per pair from whatever the weight-generation
scheme is), not two independently-weighted subjects subsequently
averaged.

**For blocking designs** where `get_block_ids()` happens to coincide with
the KK matched pairing (uncommon, and not guaranteed even for blocking
designs in general, since KK pairing is a separate greedy-match step),
the two subjects in a pair could share the same block weight already,
making the `mean()` a no-op for those specific pairs — this is a smaller
population within the flagged rows and doesn't change the conclusion for
the majority of tested designs.

## `InferenceContinKKGLMM` — NOT explained by this mechanism

Read directly (`inference_mixin_kk_glmm_shared.R`,
`inference_count_KK_combined.R`): this class does **not** call
`kk_pair_and_reservoir_bootstrap_weights()` at all. Its
`compute_weighted_glmm_bootstrap_estimate()` passes **per-row**
`row_weights` directly into a weighted GLMM fit
(`fit_weighted_glmm_on_data()`), using the KK pair id (`m_vec`) as a
**random-effect grouping factor** (`group_id`), not as a weight-averaging
key. This is architecturally sound (each subject keeps its own
independently-drawn weight; the pair structure is modeled, not
weight-averaged) — its 3 `low_coverage` findings are NOT explained by
this bug and need independent, lower-priority root-causing (only 3
findings, deprioritized per this investigation's scope).

## TODOs

- [ ] TODO-1: Reproduce empirically — draw a true-null fixture through
  `kk_pair_and_reservoir_bootstrap_weights()` directly (small isolated
  script, not the full package) and confirm `Var(pair_weights)` from the
  averaging path is roughly half of `Var(row_weights)` for a
  representative n, validating the variance-halving argument numerically
  rather than just algebraically.
- [ ] TODO-2: Confirm via `pkgload::load_all(".", compile = FALSE)` that
  fixing the collapse (see candidate fix below) measurably improves
  coverage for `InferenceContinKKOLSOneLik` on a small repro (never
  `R CMD INSTALL`/build — hard project rule, top-level `CLAUDE.md`).
- [ ] TODO-3: Design the fix. Candidate: draw bootstrap weights at the
  pair/reservoir-unit level directly for KK matched-pair-and-reservoir
  designs specifically, rather than at the subject level then collapsing
  — this likely requires a KK-specific override of the weight-generation
  step (not just the consumption step in `kk_pair_and_reservoir_bootstrap_weights()`),
  since fixing only the collapse formula (e.g. drawing a fresh single
  weight per pair post-hoc) would break the correlation between a
  subject's weight elsewhere in the analysis (e.g. the reservoir
  component) and its matched-pair component, if the same subject appears
  in both places for a different draw. Needs design thought, not a
  one-line patch.
- [ ] TODO-4: Once fixed, verify whether this fully or only partially
  explains each of the 3 classes' `low_coverage` findings (the
  `~1 compute_jackknife_wald_confidence_interval`/`compute_rand_bootstrap_confidence_interval*`
  OVER-coverage outliers noted above are likely NOT explained by this
  mechanism — investigate separately if they persist post-fix).
- [ ] TODO-5: Check whether any OTHER class calling
  `kk_pair_and_reservoir_bootstrap_weights()` beyond this investigation's
  3 (grep confirmed callers in `inference_continuous_KK_ols_one_lik.R`,
  `inference_continuous_KK_robust_regr_one_lik.R`,
  `inference_all_KK_quantile_regr_one_lik_abstract.R`,
  `inference_mixin_kk_passthrough.R`,
  `inference_incidence_KK_cond_logit.R`,
  `inference_all_abstract_KK_passthrough_compound.R` — not all of these
  were individually confirmed to hit the buggy averaging path in this
  investigation, only the 3 flagged-by-audit classes were) shows the same
  undercoverage shape; this fix may have wider blast radius than these 3
  classes.
- [ ] TODO-6: Separately root-cause `InferenceContinKKGLMM`'s 3
  `low_coverage` findings (not this bug) — low priority given the small
  finding count.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn
(top-level `CLAUDE.md`); verify via `pkgload::load_all(".", compile =
FALSE)` only, never a full build.
