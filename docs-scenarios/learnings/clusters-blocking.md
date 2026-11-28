# Learnings: clusters-blocking

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- DesignFixedCluster: unequal cluster sizes, prob_T = 1/3, numeric cluster IDs, NA cluster ID, wrong cluster_col, n = NULL (fails, F5), w_precomputed coded 1/2 (F4) and varying within clusters (F6), 3 clusters.
- DesignFixedBlockedCluster: unequal schools per district with equal pupil totals (works), unequal pupil totals (errors, F1), integer strata codes, continuous strata col (quantile bins → unequal blocks error), cluster spanning blocks (clear error), set_m() (does not help).
- InferenceContinOLS and InferenceContinLin CR2 Wald CI/p vs estimatr lm_robust/lm_lin CR2: exact match, including Satterthwaite df.
- Randomization p and CI, cluster bootstrap with every CI and p type, approximate_bootstrap_distribution_beta_hat_T with bootstrap_type NULL/within_blocks/resample_blocks, jackknife with unit auto/cluster/block/observation (cluster jackknife matches a hand-coded leave-one-school-out SE on DesignFixedCluster).
- edi_cluster_independence_warning on SimpleAverageDiff and on the OLS likelihood family; edi_cluster_col_in_model_formula_warning.

## Not reached
- Coverage simulation for blocked-cluster CR2 and randomization CI with unequal cluster sizes and few clusters per block (e.g. 2 per block).
- m-out-of-n and subsampling at the cluster level (n_units = clusters?), select_optimal_m_out_of_n_bootstrap, Bayesian bootstrap on cluster designs.
- Non-continuous outcomes on cluster designs (incidence, count, survival) and their independence warnings.
- InferenceSuite on a cluster design; DesignFixedCustom as a route to blocked-cluster randomization with unequal blocks.
- Whether compute_rand_* caches across different `r` or `delta` the way the bootstrap caches across bootstrap_type (F2).

## Workarounds
- Unequal blocks in a blocked-cluster trial: randomize within blocks in base R and declare DesignFixedCluster + w_precomputed (the re-randomization then ignores the blocks), or build data with equal pupils per block.
- Use a new inference object for each bootstrap_type and for the reported bootstrap CI (F2).
- Help text was read with tools::Rd2txt on the installed Rd database (help pages only).

## Confusing docs
- ?DesignFixedBlockedCluster: no mention of the equal-block-size requirement or that the jackknife is NA; the error message points to DesignFixedBlocking arguments.
- ?InferenceJackknife: the legal `unit` values ("auto", "cluster", "block", "observation") are not listed; "For blocking designs, this uses leave-one-block-out", but on DesignFixedBlockedCluster "auto" resolves to "cluster" (then NA).
- ?DesignFixedBlocking says "Changed in 1.0.5" while the installed package reports 1.0.4.
- compute_bootstrap_confidence_interval/pval have no bootstrap_type argument, so "resample_blocks" only reaches them through the cache (F2).
- ?InferenceContinOLS Description says SEs are "closed-form OLS variance under homoskedastic errors"; the CR2 switch on cluster designs is only in the design pages and the article.

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

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
