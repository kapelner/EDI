# Summary: sequential-designs, 2026-11-28 (EDI 1.0.5)

## What I set out to do
I simulated a clinic trial with open enrollment (`n = NULL`): 60 patients arriving about every 6 days over roughly a year, two continuous baseline covariates (`age_z`, `severity`), a continuous outcome measured 4 to 13 weeks after enrollment, and a true effect of 0.8. Four outcomes (subjects 38, 44, 51, 57) were entered very late, after enrollment closed, in reverse order. A careful applied statistician would want:
- assignment at arrival that balances the covariates;
- an allocation that can be reproduced from the seed and the event log, including after a save and reload;
- outcomes recorded whenever they arrive;
- an interim look (secondary or descriptive only, since the docs state there is no interim or stopping rule);
- a final analysis with estimate, 95% CI and p-value, checked against `lm()` / `sandwich`.

## What I finished (analysis.R, output in analysis_output.txt)
- **Designs:** Efron, Atkinson, KK14 and KK21, all with `n = NULL` and `seed = 7041`, ran through calendar-ordered enrollment and outcome events, with `runif()` noise in the session between events.
- **Interim look at enrollment 40** (41 enrolled because of a tied day; 24 outcomes known):
  - Inference on the live design is refused ("This experiment is incomplete as all responses aren't recorded yet."), which matches the docs.
  - (a) A complete-case `InferenceContinOLS` on a `DesignFixedBernoulli` copy, as in the article.
  - (b) A replay with the same seed and the same event order, restricted to the first k = 21 enrolled subjects (all with outcomes). This rebuilds the design exactly as it stood after enrollment 21: the replayed `w` is identical to the live `w[1:21]`, and the KK pairs are kept, so the KK analysis and the randomization test use the design's real mechanism.
- **Final results** (estimate, 95% CI, p):

  | Design | Analysis | Estimate | 95% CI | p |
  |---|---|---|---|---|
  | Efron | OLS | 1.020 | [0.520, 1.521] | 1.4e-4 |
  | Atkinson | OLS | 1.050 | [0.569, 1.530] | 5.3e-5 |
  | KK14 | KKOLSOneLik | 0.975 | [0.405, 1.544] | 0.0014 |
  | KK21 | KKOLSOneLik | 0.875 | [0.405, 1.345] | 6.1e-4 |

  The interim results for each design are in analysis_output.txt. Every CI contains its estimate and every p-value is in [0, 1].
- **Cross-checks:**
  - `InferenceContinOLS` matches `lm()` exactly for all 4 designs, including with `design_formula = ~ age_z * severity` (KK14, KK21, Atkinson).
  - `InferenceContinKKOLSOneLik` matches a hand-stacked OLS with `sandwich::vcovHC(type = "HC2")` (KK14 and KK21; estimate and SE to 4 digits).
  - `InferenceContinKKOLSIVWC` matches a hand IVWC of an OLS fit on the pairs and one on the reservoir with HC2 variances (0.4029). Its `~ 1` version matches the unadjusted hand IVWC (-0.28192).
  - `InferenceContinKKGLMM` vs `lme4::lmer` ML: -0.03698 vs -0.03679 at a singular fit. This only agrees to 3 decimals and was already seen in the last run.
- **Reproducibility promises (`?DesignSeqOneByOne`, "Seed and reproducibility"), all confirmed:**
  - same seed gives the same `w` regardless of other `runif()` calls in the session;
  - neither the constructor nor assignment moves the caller's stream, with `seed` set or `seed = NULL`;
  - repeated `draw_ws_according_to_design()` calls return identical draws;
  - save/`readRDS()` at enrollment 40 continues exactly, for all 4 designs;
  - for KK21, swapping two outcomes entered between the same two enrollments leaves the allocation unchanged;
  - `set_seed()` makes the randomization p-value reproducible, the fallback to the design seed gives the same p from fresh inference objects, and the session stream is untouched.
- **Matching promises, all confirmed:**
  - every KK pair has one treated and one control subject;
  - KK21 weights start once 2(p+2) = 8 responses are known (the first non-NULL iteration weight is at t = 9);
  - with `n = NULL`, `t_0_pct` is ignored (0.9 gives the same allocation as the default) and matching starts after p + 2 subjects;
  - `get_matching_cluster_ids()` has length t.
- **Other options exercised:**
  - KK21 `num_boot` = 50, 2000, and invalid values (0, -5, 10.5, NA), all rejected with clear messages;
  - `seed` validation (7041.5, "abc", NA, -3, c(1,2), 2^31 all rejected; 0 accepted);
  - `missingness_method` `impute` / `drop_column` / `error` under `n = NULL` (`drop_column` matches `lm(y ~ w + severity)`);
  - Pocock-Simon `strata_cols`, `weights` and `p_best` validation;
  - KK21stepwise, RandomBlockSize, Urn and Bernoulli all run with `n = NULL`; iBCRD refuses `n = NULL` with a clear message;
  - Efron `weighted_coin_prob = 1` keeps |nT - nC| <= 1;
  - the article's covariate coercion claim ("1.7a" is refused and the design is left as it was; "1.7" is converted);
  - subject n + 1 is refused;
  - an inference object built at a pause keeps its snapshot after more subjects enroll;
  - the bootstrap is refused on every sequential design;
  - a null-effect KK21 trial run through 10 KK and non-KK inference classes, all with finite CIs that contain the estimate.

## New findings (findings.md)
- **F1:** with `missingness_method = "error"`, KK14 and Atkinson accept a subject with an `NA` covariate if it arrives early, then refuse every later complete arrival, so the trial is stuck.
- **F2:** the KK14 matching cutoff with `n = NULL` is not documented; the formula needs the planned `n`.
- **F3:** `?DesignSeqOneByOnePocockSimon` describes an i.i.d. bootstrap that the design does not offer.

## Could not do / not reached
- `InferenceSuite` on an `n = NULL` design, and the GLMM parametric bootstrap (known finding F4). I spent the time on the `n = NULL` designs instead.
- A survival or incidence outcome under `n = NULL` KK.
- KK21stepwise `condition_on_ws_for_rand_tests = FALSE`. The probe script failed on an earlier unrelated `lmer` formula error before reaching it, and I did not rerun it.

## Places I had to guess
- **Interim analysis:** the docs only say there is none ("The sequential designs have no interim analysis or stopping rule"). I chose (a) the article's complete-case copy and (b) a seeded replay of the first k enrolled subjects. The replay is my own construction, justified by the documented per-subject seeding. I verified that it reproduces the live `w[1:k]`.
- **KK cross-check:** I took the HC2-based CI to use a t quantile with the stacked OLS residual df, as the last run found. The implied SE matches HC2 exactly under that assumption.
- **`get_n()` on an `n = NULL` design** returns the current t (20L after 20 subjects). That is not documented, but I did not treat it as a finding.
- **Very late outcomes:** I moved them to subjects 38 to 57 so the interim replay has a usable k. With an early very-late subject (7), k was only 6.

## Known findings re-checked
- `ds-sequential-designs-44358267779-f1` (closed): fixed. With `n = NULL`, `check_experiment_completed()` returns FALSE, then TRUE once all responses are in, and every Inference class I tried constructs and gives finite results.
- `ds-sequential-designs-44358267779-f2` (closed): fixed. KK14 and KK21 with `n = NULL` assign all 60 subjects; matching starts at t = 5.
- `ds-sequential-designs-44358267779-f3` (closed): fixed. `lambda = 2`, `lambda = -0.1` and `t_0_pct = 1.5` are rejected at construction with "lambda must be a single number with 0 <= lambda <= 1." (and the matching message for `t_0_pct`).
- `ds-sequential-designs-44358267779-f4` (closed): not re-checked.
- `ds-sequential-designs-44358267779-f5` (closed): not re-checked (`InferenceSuite` not run).
- `ds-sequential-designs-44358267779-f6` (closed): fixed. With `n = NULL`, outcomes recorded out of order (including 4 very late ones in reverse order) are accepted for all 4 designs. A response for a not-yet-enrolled subject is still refused, correctly.
