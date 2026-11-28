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
