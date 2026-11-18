# Summary: clusters-blocking (EDI 1.0.4), run of 2026-11-18

## Goal
A district randomizes 24 schools of unequal size (12–60 pupils), blocked by district (8/6/6/4 schools), to a reading programme. Pupils are the units of observation. A careful applied statistician would want:
- an assignment where whole schools are randomized, half within each district;
- an outcome model with a school random effect (SD 4) plus pupil noise (SD 8), adjusted for pretest and district;
- an estimate, 95% CI and p-value whose uncertainty is driven by the 24 schools, not the ~650 pupils. That means CR2 / Satterthwaite Wald, a randomization test that re-randomizes schools within districts, a cluster bootstrap and a cluster jackknife, all cross-checked against standard packages.

## What I finished (`analysis.R`, output in `analysis_output.txt`)
- **Trial 1, the real structure (districts of 106/131/184/216 pupils).** `DesignFixedBlockedCluster` refuses unequal blocks (F1, F8). Workaround: I randomized schools within districts in base R, then declared `DesignFixedCluster` with `w_precomputed` and `district` as a covariate. Its re-randomization ignores the blocking, so it is a slightly different reference distribution from the one actually used.
  - OLS CR2: 4.42, CI (0.12, 8.73), p = 0.045. Matches `estimatr::lm_robust(se_type = "CR2")` to all printed digits, including df = 17.2.
  - Lin CR2 matches `estimatr::lm_lin` exactly.
  - Randomization: p = 0.044, CI (0.02, 8.98).
  - Cluster bootstrap: percentile CI (0.37, 8.95); bootstrap-t CI (1.19, 7.72).
  - Jackknife with `unit = "cluster"` (and `"auto"`): SE 2.2853, equal to my hand-coded leave-one-school-out SE.
  - lme4 random intercept: 4.45 (SE 1.71).
- **Trial 2: `DesignFixedBlockedCluster` with equal pupils per district (168 each) but unequal schools.** Checked on 1000 redraws that the treatment is constant within schools and that exactly half of each district's schools are treated. Per-school treatment probability ≈ 0.5.
  - OLS and Lin CR2 match estimatr exactly.
  - The randomization CI contains the estimate.
  - Within-block and resample-block bootstrap work only when each uses a fresh inference object (F2).
  - The jackknife is NA for every `unit` (documented in the article).
- **Trial 3: same design, null effect.** No method rejects at the 5% level: OLS p = 0.28, randomization p = 0.30, bootstrap p = 0.27. The naive diff-in-means Wald CI is about half as wide as the CR2 CI and comes with `edi_cluster_independence_warning`.
- **Other checks:**
  - `prob_T = 1/3` treats 8 of 24 schools in every draw.
  - An NA cluster ID gives a clear error, and so does a cluster column missing from `X`.
  - Integer district codes work as strata.
  - A cluster that spans two blocks gives a clear error.
  - `cluster_col` inside `model_formula` warns as documented. The result is then a CR2 CI (−3.48, −3.32) with p = 5e-28 for an aliased coefficient; the warning had told me it is not identifiable, so I did not file it.
  - 3 clusters: CR2, randomization and bootstrap all run.
  - BCa returns NA with a clear message on blocked cluster.

## New findings (see findings.md)
F1 false error message (equal_block_sizes/B_target); F2 bootstrap draws cached across `bootstrap_type` and leaking into CIs; F3 circular advice in cluster/jackknife warnings on blocked-cluster; F4 1/2-coded w accepted → silent NA; F5 `n = NULL` default fails; F6 within-cluster-varying `w_precomputed` accepted; F7 prepivoted/double-bootstrap/calibrated NA with uninformative reason; F8 help page silent on blocked-cluster restrictions.

## Not done / why
- No proper coverage simulation for the blocked-cluster CR2 and randomization procedures (time).
- Prepivoted and double-bootstrap on `DesignFixedCluster` take about 2 min at B = 41, so I ran them only once. I did not try `calibrated` there because it timed out.
- No m-out-of-n or subsampling at the cluster level, no Bayesian bootstrap, no non-continuous outcomes.
- No tool fits an exact cross-check for a randomization test that respects the blocking when blocks are unequal, because EDI cannot express that design.

## Places I had to guess
- Whether `set_m()` on `DesignFixedBlockedCluster` would bypass covariate blocks the way it does for `DesignFixedBlocking`. It is listed by `names()` but not documented for this class. It did not bypass them.
- Trial 1's fallback design (`DesignFixedCluster`) does not reproduce the blocked randomization. I accepted that as the documented-closest option.
- I took "prob_T = 0.5 → half of clusters per block" to hold under rounding. With even numbers of schools per district it held exactly.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area.

## Cross-check packages
estimatr (CR2), lme4, and base `lm` were available and used. clubSandwich is not installed; estimatr provided the CR2 reference instead.
