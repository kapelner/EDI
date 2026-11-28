# Summary: clusters-blocking (EDI 1.0.5, 2026-11-28)

## Goal
A district randomizes 24 schools (12-60 pupils each, 690 pupils), blocked by district with unequal blocks (7/6/6/5 schools; 155-225 pupils per district), to a reading program. Outcome: end-of-year score with a school random effect (SD 4, pupil SD 8, ICC about 0.2). A careful applied statistician wants three things. First, an assignment that is constant within schools and balanced within districts. Second, an adjusted effect estimate with a cluster-robust CI and p-value whose df reflects 24 schools, not 690 pupils. Third, a design-based randomization test and cluster-level resampling as sensitivity checks, plus evidence that no reported number treats pupils as independent.

## Done (analysis.R, output in analysis_output.txt)
- Design: `DesignFixedBlockedCluster` with `n = NULL`, unequal school and district sizes, odd school counts per district (7 and 5), `seed`. Assignment is constant within schools. The 2000 redraws treat 3 or 4 (North) and 2 or 3 (West) schools at random, with per-school marginal probabilities of about 0.5. The same seed gives the same `w`.
- Reported analysis (true effect 3): OLS adjusted for district, pretest and FRL. CR2 estimate 2.08, 95% CI [-1.98, 6.13], p = 0.294. This matches `estimatr::lm_robust(CR2)` and `clubSandwich::coef_test(CR2, Satterthwaite)` to all printed digits (df 16.04). Lin: 1.89 [-0.85, 4.63], p = 0.160, an exact match with `lm_lin`. Randomization p = 0.336 against a hand-coded test from the same design redraws, p = 0.332. Randomization CI [-2.10, 5.94]. Cluster-within-district bootstrap percentile CI [-1.63, 4.88]; its SD matches a hand-coded within-district school bootstrap (1.65 vs 1.60). m-out-of-n and subsampling resample clusters (n_units = 24, m = b = 9; m > 12 errors with a clear range). The blocked Bayesian bootstrap uses cluster-within-stratum weights (SD 1.23 vs 1.20 hand). Null-effect data set: every procedure gives p of 0.31-0.35.
- Same trial declared as `DesignFixedCluster`: CR2, cluster jackknife (equal to a hand leave-one-school-out SE, 2.3245) and cluster bootstrap all agree. The Bayesian bootstrap does not (F1).
- Binary proficiency outcome on both cluster designs: the randomization test is unusable (F4, F5).
- InferenceSuite on a cluster design (F3). Recorded-assignment route with `w_precomputed` (F2).
- Every CI contains its estimate, every p-value is in [0, 1], and no NA appeared without a warning that explains it.

## Not done / why
- The prepivoted, double-bootstrap and calibrated bootstrap CIs at B = 801 did not finish in 10 minutes (the run was killed). At B = 25 each took about 80 s, so they are not in analysis.R. At B = 25 "calibrated" and "prepivoted" gave identical intervals; I did not check whether that is intended.
- No coverage simulation, for lack of time (see learnings_update.md).
- lmerTest and fwildclusterboot are not installed. A mixed model was not used as a reference, because EDI has no mixed-model analysis for clusters (stated in the article).

## Guesses / decisions
- Reported the CR2 OLS result as primary, with the randomization test as the design-based check. With only 24 schools the docs warn that the bootstrap is anti-conservative.
- The observation_within_block jackknife (SE 0.64 vs CR2 1.91, p = 0.001) is documented as "not a cluster-robust variance". I did not report it and did not log it as a finding, although it emits no `edi_cluster_independence_warning`.
- InferenceSuite's combined-evidence p (0.0067, driven by the warned Wald row and the F1 Bayesian-bootstrap row) is covered by the documented caveat, so it is not a finding.
- Help text was read with `tools::Rd2txt` on the installed Rd database (help pages only).

## Known findings re-checked
- ds-clusters-blocking-44358267779-f1 (closed): fixed. Unequal block sizes on DesignFixedBlockedCluster now work, and the help page says so.
- ds-clusters-blocking-44358267779-f2 (closed): fixed. "within_blocks" and "resample_blocks" give different draws on one object (SD 1.57 vs 2.92).
- ds-clusters-blocking-44358267779-f3 (filed): still reproduces. `unit = "cluster"` says to use `unit = "block"`, and `"block"` (4 districts) is NA and says to use "the model-based standard error". The incidence version of the same warning also recommends `compute_rand_two_sided_pval()`, which errors (F4).
- ds-clusters-blocking-44358267779-f4 (closed): fixed. A 1/2-coded `w_precomputed` errors with "w_precomputed must contain only 0 (control) and 1 (treatment); found 2."
- ds-clusters-blocking-44358267779-f5 (closed): fixed. `n = NULL` works on both cluster designs.
- ds-clusters-blocking-44358267779-f6 (closed): fixed. A `w_precomputed` that varies within schools errors with a clear message on both designs.
- ds-clusters-blocking-44358267779-f7 (closed): fixed. prepivoted, double-bootstrap and calibrated now return finite CIs on a blocked-cluster design (but they are slow, see above).
- ds-clusters-blocking-44358267779-f8 (dismissed): not re-argued. The help page now documents both points.
