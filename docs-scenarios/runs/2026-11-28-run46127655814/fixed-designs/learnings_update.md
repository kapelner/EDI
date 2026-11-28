## Covered
- DesignFixedBlocking: `strata_cols` (continuous, categorical-integer, both), `preferred_num_bins_for_continuous_covariate = 4`, `B_target` (2/3/4/5/7/8/14/20), `exact_num_blocks`, `equal_block_sizes = FALSE`, user `m` (with and without `n`), `summarize_blocks()`, `prob_T = 0.4`.
- DesignFixedOptimal: A-optimality with `interest = ~weight`, `"weight"` and `"all"`; `prior_precision` scalar and matrix (wrong dimension and negative errors); `standardize_covariates = FALSE`; `solver_args` (`n_chains`, `max_iter`, `milp_time_limit`, unknown-key and `roi_solver` validation); `mirror_coin = FALSE`; exact MILP/Dinkelbach vs annealing at n = 16; `prob_T = 0.25/0.4`; custom-objective argument validation; bootstrap-randomization CI and p.
- GreedyDOptimal with `prior_precision` 5/100/1e4 (draws differ from the no-prior design as documented); Greedy `design_formula = ~ weight + age + I(weight^2)`.
- Missing covariates: `missingness_method` impute/drop_column/error × `include_is_missing_as_a_new_feature` for Rerandomization, Greedy, Optimal and BinaryMatch.
- `w_precomputed` validation (2/0 coding, wrong length, logical); a null effect with Rerandomization `prop_acceptable` at `prob_T = 0.4`.
- Bootstrap CI and p across all fixed designs at `n = NULL` vs `n = 40`.

## Not reached
- BlockedCluster, Cluster, Factorial, OptimalBlocks; custom C++ objective compile and run; `brt_solver` / `brt_max_iter`.
- Size or coverage of the bootstrap-randomization CI for DesignFixedOptimal (a single null data set gave p = 0.02 for the unadjusted mean difference: worth a size simulation).
- Do other covariate-free designs (Bernoulli at `n = NULL` was fine) or blocking-capable classes share F4's block-id bug in the jackknife or the m-out-of-n bootstrap?
- iBCRD `capabilities()` lists "blocking" only when `n` is given: is it treated as one block?

## Workarounds
- For blocking on a continuous covariate with ties at the bin edges, quantile bins cannot be equal-sized: use `m = rep(1:K, each = n/K)[rank(x, ties.method = "first")]` with `n = n`.
- Pass `n = nrow(X)` to DesignFixediBCRD before using any bootstrap (F4).
- A BCa boundary warning at small B returns NA. The default B = 501, or `type = "percentile"`, fixes it, as the warning says.
- Bootstrap draws use the global RNG: `set.seed()` right before the inference call makes results reproducible.

## Confusing docs
- ?DesignFixedBlocking: the default `B_target` is given two ways (largest divisor ≤ floor(sqrt(n)) with `n` known, floor(sqrt(n)) with `n = NULL`), and the "always satisfies equal_block_sizes" claim only concerns divisibility. Quantile bins on real data rarely give equal sizes.
- ?DesignFixedOptimal: for `objective = "D"`, `objective_value` is w'Pw (≈ n_T²/n + imbalance), the minimized form, not s(w); "other objectives report the solver's value" leaves this to guesswork.
- ?DesignFixedGreedy / ?DesignFixedGreedyDOptimal point to internal files (`fix_design_hierarchy.md`, `package_metadata/...`) that users cannot read.
- ?Design `missingness_method` says it applies "when building the model matrix for inference", but it also determines the covariates that the balance criteria (rerandomization, greedy, optimal) use.
