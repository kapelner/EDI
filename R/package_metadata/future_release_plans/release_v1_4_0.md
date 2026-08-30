# Release Scope: v1.4.0 — Response and Data Extensions

> **Depends on:** `release_v1_3_0.md`. Last 1.x release before 2.0.0.
> Release index over plans in `../new_feature_plans/`. (Global ordering:
> see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (thematic 1.x split). **Theme.** Everything that adds
information *to the data a design carries* or extends an existing
response type's semantics without introducing a new response shape:
censoring bounds on continuous / count / proportion outcomes, a cause code
and cure fraction on survival outcomes, a treatment-received column
(encouragement designs), a moderator role for a covariate, missing
outcomes, and the survival quantile-regression estimator. Also the
one hard field-name break already decided by the user (`dead →
uncensored`), placed here so it ships in the same sweep as the new
`event_type` column, and the sequential-inference scoping that prepares
2.0.0.

## In scope (by plan)

`wilcox_hl_kernel_hoisting.md` (added 2026-08-30; `→ TODO-1..6`; see
`TODO-11e` below) — exact, bit-identical hoisting inside the live Wilcoxon–HL
randomization kernel.

`ridit_kernel_level_slots.md` (added 2026-08-30; `→ TODO-1..5`; see
`TODO-11f` below) — bit-identical level-slot precomputation in the ridit
randomization and bootstrap kernels.

`kk_signed_rank_hoisting.md` (added 2026-08-30; `→ TODO-1..5`; see
`TODO-11g` below) — bit-identical rank hoisting in the KK matched-pair
signed-rank randomization kernel.

`rerandomization_objective_vals_gemm.md` (added 2026-08-30; `→ TODO-1..5`;
see `TODO-11h` below) — GEMM accumulation and whitened Mahalanobis scoring in
the rerandomization objective kernel (tolerance-equal; ranking caveat).

`small_kernel_hoists_batch.md` (added 2026-08-30; `→ A..D, TODO-E`; see
`TODO-11i` below) — four small independent kernel hoists (greedy Gram
matrix, ordinal `y_slot`, Cox bootstrap ordering, shared GH rule).

### Survival-model extensions (one plumbing sweep)
- `../finished_features/interval_censored_survival_response.md → TODO-29`
  — the **`dead → uncensored` rename** (R, C++, Python binding; hard break,
  user decision 2026-08-19). Do it in the same sweep as:
- `competing_risks_response.md` — `event_type` cause code on `survival`;
  cause-specific Cox / log-rank recode wrappers; Aalen-Johansen CIF
  difference, Gray's test, RMTL; Fine-Gray via `cmprsk` delegation (native
  counting-process Cox kernel deferred to a later kernel spec). Decision-
  gated; v1 = exact/right-censored only.
- `cure_fraction_survival_inference.md` — `InferenceSurvivalMixtureCureWeibull`
  (+ optional promotion-time variant) via the `estimand` axis;
  `flexsurvcure` delegation first, native kernel second. Decision-gated.
- `interval_censored_survival_response_type_report.md → second wave` (if
  decided yes) — NPMLE/Turnbull Cox-analogue, stratified `icenReg`,
  current-status estimator (new implementation plan; do not reopen the
  finished one).
- `survival_quantile_regression.md` — custom self-consistent EM censored
  QR + KK IVWC/OneLik; approved design with three recorded open risks,
  each to be closed by a test before export.
- `full_glmm_for_weibull_frailty.md` — Weibull-frailty classes generalized
  from pairs to k-strata; `allow_k_wise_groups` opt-in (depends on the
  rename).

### Censoring on the other scalar types
- `censored_continuous_response.md` — generalizes the `y_L`/`y_R` bounds
  schema to `continuous`; Tobit kernel inside OLS; Lin / `crq` / robust /
  KK variants.
- `censored_count_response.md` — censored Poisson/NB; binned counts.
- `betaregscale_duplication.md` — interval-censored beta regression with
  variable dispersion.
- `semi_continuous_response_type_report.md` (if decided yes) — hurdle
  log-normal / gamma on the `continuous` type (no new enum).

### New per-subject data roles
- `encouragement_design_cace.md` — `treatment_received` column;
  `InferenceAllCACEWald`, `InferenceContin2SLS` / `Incid2SLS` (uses the
  1.1.0 HC-robust helper).
- `treatment_covariate_moderation.md` — `moderator =` with
  `"interaction"` / `"subgroup"` estimands and the forest-plot table.
- `missing_outcome_handling.md` — missing-outcome representation, Lee /
  Manski bounds, multiple-imputation wrapper with Rubin's rules, IPW for
  attrition, tipping-point sensitivity.

### Preparation for 2.0.0
- `sequential_inference.md → TODO-1..5` — the **scoping** (design-side
  ledger audit, public-accessor targeting, decision on 2.0.0 vs later);
  implementation is `release_v2_0_0.md → TODO-5`.
- `nominal_response_type_report.md → TODO-1b` — if its TODO-1 is decided
  "no" (recorded recommendation), the one-vs-rest recode vignette section
  ships here and the report closes.

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Phase 0 decisions** still open for this release's gated
  items (`competing_risks → TODO-1`, `cure_fraction → TODO-1`,
  `interval_censored second wave`, `semi_continuous → TODO-1`,
  `full_glmm_for_weibull_frailty → TODO-0`) — take in the 1.1.0 sitting.
- [ ] TODO-2: **Survival plumbing sweep** — the `dead → uncensored` rename
  and `competing_risks_response.md → TODO-2` (Wave 0: `event_type`
  storage, replay, save/load) in one pass over the 31 `Surv()` sites and
  `get_effective_dead()`; golden bit-for-bit for every existing survival
  class with `event_type = 1`.
- [ ] TODO-3: **Competing risks Waves 1–3a** `competing_risks_response.md
  → TODO-3..5`; Wave 3b kernel and `SimulationFramework` (`→ TODO-6..8`)
  may trail into 2.0.0.
- [ ] TODO-4: **Cure fraction** `cure_fraction_survival_inference.md →
  TODO-2..6`.
- [ ] TODO-5: **Weibull-frailty k-strata** `full_glmm_for_weibull_frailty.md
  → TODO-1..40`.
- [ ] TODO-6: **Interval-censored second wave** (if yes) — new
  implementation plan, then execute.
- [ ] TODO-7: **Survival quantile regression** — implementation plan
  (writing-plans step), then execute with the three risk-closing tests.
- [ ] TODO-8: **Censoring track** `censored_continuous_response.md →
  TODO-1..12` → `censored_count_response.md → TODO-1..14` →
  `betaregscale_duplication.md → TODO-2..12`; then `semi_continuous →
  TODO-2..6` if decided yes.
- [ ] TODO-9: **Encouragement / CACE** `encouragement_design_cace.md →
  TODO-1..4`.
- [ ] TODO-10: **Moderation** `treatment_covariate_moderation.md → TODO-1..5`.
- [ ] TODO-11: **Missing outcomes** `missing_outcome_handling.md → TODO-1..5`.
- [ ] TODO-11b: **Model-averaged point estimate/CI for `InferenceSuite`**
  (added 2026-08-30, moved here from v1.1.0 by user decision):
  `model_averaged_estimand_report.md → TODO-1..5` — a model-averaged point
  estimate/CI across `InferenceSuite`'s applicable models (Buckland, Burnham
  & Augustin 1997 variance formula, Akaike or inverse-variance weights),
  complementing the existing Cauchy combination-test `combined_evidence$pval`
  and `wilkinson_combined_pval.md`'s vote-count/order-statistic work (both
  v1.1.0) with an actual reportable number instead of another existence
  test. Stage 1 (within one estimand group) is additive with no new
  dependency; Stage 2 (across estimand groups, e.g. different link
  functions) depends on the already-shipped `set_estimand("marginal_*")`
  machinery. Independent of every other item in this release.
- [ ] TODO-11c: **Multiplicity-adjusted `results_table`** (added
  2026-08-30): `multiplicity_adjusted_results_table.md → TODO-1..5` — Holm
  (FWER, valid under arbitrary dependence, no calibration audit needed) and
  Benjamini-Hochberg (FDR, gated on a PRDS calibration check under this
  package's actual dependence structure) adjustment applied directly to
  `results_table`'s raw p-values, estimand-grouped by default. Answers a
  different question from `combined_evidence$pval`/TODO-17n's vote-count and
  IUT work (both v1.1.0) and this release's TODO-11b model-averaging: not
  "is there evidence anywhere/most/everywhere" or "what's the best single
  estimate," but "which *specific* rows survive correction." Thin wrapper
  over `stats::p.adjust()` — no new statistical machinery for the Holm half;
  independent of every other item in this release.
- [ ] TODO-11d: **Selective (post-selection) inference for
  `InferenceSuite`** (added 2026-08-30): `selective_inference_post_selection.md
  → TODO-1..6`, scoped to Phase 0 + a single pilot class
  (`InferenceContinOLS`) — the technically strongest honest answer to "I
  looked at k models and picked the best one," deriving p-values/CIs
  already valid conditional on the selection event (PoSI, Berk et al. 2013,
  or data carving, Fithian/Sun/Taylor 2014) without sacrificing data to a
  split, unlike TODO-6e in `release_v2_0_0.md`. Substantially heavier lift
  than TODO-11b/c (per-model-class derivation, not a generic wrapper);
  deliberately scoped narrow here (one pilot class) so the real
  implementation cost is known before deciding whether broader rollout
  stays v1.4.0-tractable or moves to 2.0.0 alongside TODO-6e's data-carving
  stage. Coordinate Stage 0's selection-statistic decision with TODO-6e's
  (same underlying question).
- [ ] TODO-11e: **Wilcoxon–HL randomization kernel hoisting** (added
  2026-08-30, user decision): `wilcox_hl_kernel_hoisting.md → TODO-1..6`.
  The live `compute_wilcox_hl_distr_parallel_cpp` (`src/fast_wilcox_hl.cpp`)
  re-sorts `y_t`/`y_c` every replicate although `y` is fixed (sort the
  index order once; partitioning in that order yields sorted groups, and
  the δ-shift is monotone so this holds for `δ ≠ 0` too), mallocs two
  vectors per replicate inside the `omp for` (hoist per-thread as
  `ridit_distr_parallel.cpp:132` does), and bisects the HL median to
  floating-point exhaustion (~53 O(n) counting passes) when stopping once
  the bracket holds a single realised difference (~10–14 passes) and
  warm-seeding from the previous replicate (~6–10) give the identical
  snapped answer. All four changes are exact — the test contract is
  `identical()`, not a tolerance. Expected 3–4× on the Wilcoxon
  randomization distribution at `n = 500`. No dependencies.
- [ ] TODO-11f: **Ridit randomization kernel level slots** (added
  2026-08-30, user decision): `ridit_kernel_level_slots.md → TODO-1..5`.
  `compute_ridit_distr_parallel_cpp` (`src/ridit_distr_parallel.cpp`) has a
  hoisted fast path only for `reference = "pooled"`; the default
  `"control"` rebuilds the reference ridit map from scratch every
  replicate (`:94` — partition, copy, sort, unique, n binary searches).
  Precompute the sorted level set and each subject's level slot once; per
  replicate count the reference arm in O(n) (or by subtraction from the
  fixed total), build present-level scores with the identical cumulative
  loop, fill absent levels by the existing interpolation rule in O(K), and
  accumulate the treated mean in subject order so the result is
  bit-identical (`identical()` test contract). Same for the bootstrap
  sibling. Expected ~8–10× at `n = 500`. No dependencies.
- [ ] TODO-11g: **KK signed-rank kernel rank hoisting** (added 2026-08-30,
  user decision): `kk_signed_rank_hoisting.md → TODO-1..5`. The
  fixed-matching fast path of `compute_matching_wilcox_distr_parallel_cpp`
  (`src/fast_kk_wilcox_parallel.cpp:151-183`) re-sorts the pairs by `|diff|`
  and reassigns average ranks every replicate, plus three mallocs inside
  the `omp for`; at `δ = 0` the absolute pair differences, ties, ranks, and
  `all_zero` flag are permutation-invariant — only the signs flip with
  which member is treated. Hoist them once exactly as the file already does
  for the reservoir (`:129-142`); per replicate one O(m) pass. Bit-identical
  (ranks are multiples of 0.5, so the sum is exact in any order;
  `identical()` test contract). Expected ~4–5× on the pair component. No
  dependencies.
- [ ] TODO-11h: **Rerandomization objective scoring via GEMM + whitening**
  (added 2026-08-30, user decision):
  `rerandomization_objective_vals_gemm.md → TODO-1..5`.
  `compute_objective_vals_cpp` (`src/rerandomization_helpers.cpp`)
  accumulates the treated-arm covariate sums for `r` draws in a scalar
  O(r·n·p) triple loop with a branch per (subject, draw) — really one GEMM
  `indicTs · X` — and then evaluates the Mahalanobis form unwhitened with
  bounds-checked `Rcpp` indexing, O(p²) per draw, while its sibling
  `rerandomization_search_cpp` in the same file already whitens once and
  uses `squaredNorm()`. Replace with an Eigen GEMM, Cholesky-whiten `X`
  once (the sibling's balanced-`n/2` form cannot be reused verbatim since
  this function takes arbitrary `n_T` per draw), O(p) per draw. Expected
  5–15×. **Tolerance-equal, not bit-identical**, and the values are ranked
  to select allocations — a documented reproducibility change at exact
  objective ties; tests compare values to 1e-10 and selected allocations on
  well-separated fixtures. No dependencies.
- [ ] TODO-11i: **Small kernel hoists batch** (added 2026-08-30, user
  decision): `small_kernel_hoists_batch.md → A1..A3, B1..B2, C1..C3,
  D1..D2, TODO-E`. Four independent items: (A) `design_fixed_greedy.cpp`
  exhaustive Mahalanobis mode — hoist `G = MᵀM` and `g = Mᵀd` so each pair
  scores in O(1) instead of O(p), behind an `n²·8 ≤ 64 MB` guard
  (tolerance-equal; final `w` tested on separated fixtures); (B)
  `ordinal_fixed_link_helpers.h:163` — cache `y_slot` at construction
  instead of an O(K) scan per observation per L-BFGS iteration, as
  `fast_negbin_regression.cpp:71` already does (bit-identical); (C)
  `fast_coxph_regression.cpp:1129` — order each bootstrap draw by a
  counting pass over the parent's rank permutation instead of a
  comparison sort (tolerance-equal: risk-set summation order within tie
  groups may change); (D) unify the four duplicated Gauss–Hermite rule
  constructions on `_glmm_engine.h`'s and cache by `n_gh` — ~1 % of a GLMM
  fit, done for deduplication not speed (bit-identical once the copies
  are confirmed identical). No dependencies.
- [ ] TODO-12: **Sequential-inference scoping** `sequential_inference.md →
  TODO-1..5`; nominal vignette section if applicable.
- [ ] TODO-13: **Release mechanics** per `release.md`, including the
  rename's migration note (the only 1.x-era break).

## Standing constraints

As the other 1.x releases, with one exception recorded here: the `dead →
uncensored` rename is a deliberate break with a migration note; every
other default reproduces 1.3.0 bit-for-bit.
