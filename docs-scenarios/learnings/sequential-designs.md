# Learnings: sequential-designs

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- `n = NULL` on Bernoulli, Efron, Atkinson, KK14, KK21: assignment works for the non-KK designs; KK fails at t = 5 (F2); with `n = NULL`, no completeness check or Inference class works (F1).
- n = 60 trial with delayed (6-10 week) and three very late out-of-order outcomes, under Efron, Atkinson, KK14 and KK21; interim look at the 40th enrollment; final analysis.
- Cross-checks: InferenceContinOLS vs `lm()` (exact); KKOLSOneLik (adjusted and `~1`) vs a hand-built stacked OLS with `sandwich::vcovHC(type = "HC2")` (exact estimate and SE; the CI/p use t with the residual df); InferenceAllKKMeanDiffIVWC vs the article's formula (matches with pooled reservoir variance); InferenceContinKKGLMM Wald vs `lme4::lmer` ML (SE identical, estimate 0.2202 vs 0.2215 at a singular fit).
- Reproducibility: same seed gives the same w for all 4 designs; other `runif()` calls in between change it (documented); the constructor's `set.seed()` resets the session RNG (documented); `seed = NULL` + `set.seed()` reproduces; the article's save/restore of `.Random.seed` reproduces the uninterrupted run for Atkinson, KK14 and KK21 (pairs too); outcome order changes KK21's allocation but not KK14's or Atkinson's.
- Efron `weighted_coin_prob`: 1 keeps |nT - nC| <= 1; 0.5, 2, NA, and length 2 are all rejected with a clear message. `prob_T` is rejected by Efron, Atkinson and KK14 ("unused argument").
- KK14 `lambda` 0/0.5/1, `t_0_pct` 0/0.1/1, `morrison = TRUE` (warns). Response edge cases (NA, Inf, character, t = 0, t = 1.5, t > enrolled, overwrite warning): all handled with clear messages.
- Covariate edge cases: an NA value or a missing column is imputed and gets a `_is_missing` indicator; a type change warns; an extra column is accepted; two rows are rejected.
- `InferenceSuite$run_all_inference()` on a KK14 design (13 applicable classes).

## Not reached
- KK21stepwise and its `condition_on_ws_for_rand_tests`; PocockSimon / SPBR / RandomBlockSize / Urn sequential designs.
- KK21 `num_boot` and `*_use_speedup` arguments; non-continuous responses under KK.
- `missingness_method = "drop_column"` / `"error"` in a sequential design; `design_formula` with interactions.
- `InferenceBaiAdjustedTKK21` is listed as applicable to a KK14 design and gives results identical to TKK14; check whether that is intended.
- `lik_ratio_bartlett_approx` p-value differed between two suite runs on the same design (0.308 vs 0.359); check whether it is seeded.
- InferenceSuite with `compute_conf_intervals = FALSE` reports param_boot rows with status "ok" and p = NA; check what the docs promise.

## Workarounds
- n = NULL: outcomes must be entered in enrollment order (F6); buffer late outcomes and flush them when contiguous.
- InferenceSuite crash (F5): leave out `max_secs_per_class` or use `num_cores = 1L`.
- Interim look: Inference refuses an incomplete design ("This experiment is incomplete as all n subjects haven't arrived yet."). Copy the completers' X / w / y into a `DesignFixedBernoulli` (`add_all_subjects_to_experiment`, `assign_w_to_all_subjects(w_precomputed=)`, `add_all_subject_responses`) and use asymptotic results only (article "When some outcomes never arrive").
- `run_all_inference()` needs `screen = TRUE` or `html = TRUE`; it takes about 2 minutes on n = 60 KK14 with 2 cores and `max_secs_per_class = 20`.

## Confusing docs
- `?DesignSeqOneByOne*` show `n = NULL` as the default and describe it as supported, but the article "Running a Sequential Trial" says KK designs need `n`, and nothing says that n = NULL designs cannot be analyzed at all (F1).
- `?Design` "RNG/reproducibility caveat" says a reload-and-continue is "not expected to reproduce" the same draws, while the article shows how to make it exact by saving `.Random.seed`. The two are compatible, but the help page reads as if exact continuation is impossible.
- `?DesignSeqOneByOneAtkinson` names internals (`ncol(private$Xraw) + 3`, `atkinson_assign_weight_cpp()`) and refers to `prob_T` in the fallback, but the class has no `prob_T`.
- `?DesignSeqOneByOneKK14` says `morrison` is "recorded but not consulted"; at runtime it also warns (the warning is described only on KK21's page).

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

## Covered
- n = NULL end to end (Efron, Atkinson, KK14, KK21) with calendar-ordered events, out-of-order and very late reverse-order outcomes; interim at enrollment 40 and final; all closed known findings f1/f2/f3/f6 now fixed.
- New per-subject seeding (`?DesignSeqOneByOne` "Seed and reproducibility"): stream untouched by construction/assignment (seeded and seed = NULL), session noise does not change w, repeated `draw_ws_according_to_design()` identical, save/reload exact, inference `set_seed()` and design-seed fallback reproducible.
- `seed` validation (non-integer, NA, negative, length 2, > 2^31 rejected; 0 OK); KK21 `num_boot` (valid and invalid); n = NULL `t_0_pct` ignored; KK21 weights start at 2(p+2) responses.
- `missingness_method` impute / drop_column / error under n = NULL (F1); `design_formula = ~ a * b` on KK14/KK21/Atkinson matches lm with interaction.
- PocockSimon (`strata_cols`, `weights`, `p_best` validation), KK21stepwise / RandomBlockSize / Urn / Bernoulli with n = NULL; iBCRD refuses n = NULL clearly.
- Cross-checks: InferenceContinKKOLSIVWC = hand IVWC with HC2 per piece (and ~1 = unadjusted IVWC); KKOLSOneLik = stacked OLS + HC2.

## Not reached
- InferenceSuite on an n = NULL design; GLMM parametric bootstrap re-check (old f4); KK21stepwise `condition_on_ws_for_rand_tests = FALSE` timing.
- Non-continuous responses (survival with censoring, incidence) under n = NULL KK21; `*_use_speedup = FALSE`.
- `compute_rand_confidence_interval()` on KK designs vs a hand inversion (one run gave [-0.964, 0.584] for est -0.114, not verified).
- SPBR / RandomBlockSize option sweep (block sizes, strata) under n = NULL.

## Workarounds
- Interim look that keeps the design's mechanism: replay the logged events with the same seed, restricted to the first k enrolled subjects whose outcomes are all known (`only_subjects = 1:k`). The replayed w equals the live w[1:k] (per-subject seeding), pairs are kept, and Inference works because that design is complete. Requires that no early subject's outcome is very late.
- Use `day_enr[k]` interim cut-offs carefully: tied days can enroll k+1 subjects.

## Confusing docs
- `?DesignSeqOneByOneKK14`: threshold formula uses planned n; nothing says what n = NULL uses (F2).
- `?DesignSeqOneByOnePocockSimon` "Non-resampling bootstrap" paragraph describes a bootstrap the class does not offer (F3).
- `?Design` `missingness_method = "error"` says "for inference" and "as soon as any missing value is detected"; in practice Efron/Bernoulli accept NA at enrollment and only Inference errors, KK14/Atkinson error at enrollment only after their warm-up (F1).
- `get_n()` on an n = NULL design returns the current t; undocumented.
