## Covered
- DesignFixedBlockedCluster with unequal block sizes (now works), odd cluster counts per block (random rounding checked over 2000 redraws), `seed` reproducibility, `n = NULL`.
- CR2 OLS/Lin with district fixed effects vs estimatr and clubSandwich: exact. Randomization p vs a hand-coded test from `draw_ws_according_to_design()`: agree within MC error.
- m-out-of-n and subsampling on cluster designs: n_units = clusters, default m = b = floor(G^0.7), valid range max(5, p_eff + 2) to floor(G/2), enforced with a clear error.
- Bayesian bootstrap weighting_unit_type NULL / within_blocks / resample_blocks on the blocked-cluster design (cluster weights, correct) and on DesignFixedCluster (pupil weights, F1).
- Randomization bootstrap (BRT) p and CI on both cluster designs: run, about 40 s for a CI at B = 200.
- InferenceSuite on DesignFixedCluster: results_table columns regime / n_eff / size_order (F3), combined evidence.
- Incidence outcome on cluster designs: Wald warns, bootstrap works, randomization test errors (F4/F5); also errors on plain DesignFixedBlocking.
- w_precomputed that is cluster-constant but impossible under the blocked design (F2).

## Not reached
- Coverage simulation of the Bayesian bootstrap on DesignFixedCluster (expected well under 95%) and of the CR2 / randomization CI with 2 clusters per block.
- Count and survival outcomes on cluster designs; InferenceIncidCMH and InferenceIncidExtendedRobins on DesignFixedBlockedCluster.
- select_optimal_m_out_of_n_bootstrap / select_optimal_b_subsampling on clusters; subsampling_type = "resample_blocks".
- Whether `calibrated` and `prepivoted` bootstrap CIs are meant to be identical (they were at B = 25).
- Randomization CI with `delta` / `alternative` on cluster designs; prob_T != 0.5 on the blocked-cluster design.

## Workarounds
- For a binary outcome on a cluster design, a randomization test has to be hand-coded from `des$draw_ws_according_to_design()` (F4).
- On DesignFixedCluster use the cluster bootstrap or jackknife, not the Bayesian bootstrap (F1).
- Double-bootstrap CI types (prepivoted / calibrated / double-bootstrap) cost about B^2 fits: B = 25 already takes about 80 s on this 690-row design, so keep B tiny or skip them.

## Confusing docs
- ?InferenceBayesianBootstrap: says NULL means "the usual subject-level Bayesian bootstrap" for non-blocking designs without saying whether DesignFixedCluster counts as one; `compute_estimate_with_bootstrap_weights` implies cluster weights.
- ?InferenceJackknife cites "since EDI 1.0.6" and "v1.0.6-TODO-..." behaviour while the installed version is 1.0.5.
- `InferenceSuite$run_all_inference()` requires screen or html to be TRUE, so there is no silent mode; html = TRUE "auto-opens" a report.
- The cluster warning on DesignFixedBlockedCluster recommends `unit = "cluster"` for the jackknife, which this design does not support (still the known f3 loop).
