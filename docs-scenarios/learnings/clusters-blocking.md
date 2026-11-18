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
