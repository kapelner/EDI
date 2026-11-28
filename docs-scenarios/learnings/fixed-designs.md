# Learnings: fixed-designs

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- Rerandomization: obj_val_cutoff and prop_acceptable; mahal_dist and abs_sum_diff; prob_T 0.3/0.4 (pure-R path); odd n = 41; tight-cutoff error; both/neither/invalid-objective errors; scale invariance; seed reproducibility across 1 and 2 cores; checked that every draw satisfies M(w) <= cutoff.
- Greedy: defaults, abs_sum_diff, n_iter = 50/200, prob_T = 0.3, invalid n_iter/prob_T; the claimed equality with GreedyDOptimal (holds without ties, fails with ties: F3).
- Optimal: mahal_dist/D via annealing (auto above n = 20), abs_sum_diff MILP timing (n = 16, 24 fast; n = 40 hangs: F4), get_optimization_diagnostics (scale: F5), mirror coin fields, refusal of rand test, bootstrap randomization CI.
- iBCRD (0.5, 0.4), Bernoulli, BinaryMatch, PairSwitching (n % 4 error); n = NULL on 8 classes (F6).
- Inference: InferenceContinOLS (asymp, rand CI/p) matches lm; PooledVar matches t.test; randomization CI coverage over 150 reps per design.

## Not reached
- DesignFixedBlocking (strata_cols, B_target, exact_num_blocks, equal_block_sizes = FALSE, user m), BlockedCluster, Cluster, Factorial, OptimalBlocks.
- DesignFixedOptimal objective "A" with interest = "all"/formula, prior_precision scalar/matrix, standardize_covariates = FALSE, custom C++ objective, solver_args (linearization_max_n, n_chains, brt_solver), Dinkelbach path.
- GreedyDOptimal "A"/prior_precision; BinaryMatch mahal_match = FALSE, match_objective = "squared_distance", user m.
- Missing covariates (missingness_method, include_is_missing_as_a_new_feature) in fixed designs; design_formula with interactions.
- Does F1 also affect other "All*" classes, or other procedure pairs (e.g. bootstrap p-value then asymp)?
- Is the size inflation in F2 present for OLS or for larger prop_acceptable?

## Workarounds
- Seeded fixed designs call set.seed() on the global RNG at assignment, so generate outcomes BEFORE building the design. Otherwise your later rnorm() can repeat your covariate draws (I got a perfect fit this way).
- Compute asymptotic results before randomization p-values, or use a new inference object per procedure (F1).
- Use solver = "annealing" for DesignFixedOptimal abs_sum_diff with n > ~24 (F4).
- Always pass n = nrow(X) (F6).
- `diff(ci)` keeps the "97.5%" name. unname() before naming in c(), or column names get mangled.

## Confusing docs
- ?DesignFixedRerandomization: no guidance on choosing obj_val_cutoff for a target acceptance rate. prop_acceptable's "large-draw limit" caveat hides that the observed assignment is always an r = 1 draw (F2).
- ?DesignFixedOptimal: "always [MILP] for abs_sum_diff" with no size caveat or time limit (F4); the diagnostics' objective_value scale is undocumented (F5).
- Help for compute_rand_bootstrap_confidence_interval was not found from ?DesignFixedOptimal; I had to find the method name via ls() on the inference object.
- The error message for a randomization test on DesignFixedOptimal suggests asymptotic and plain bootstrap but not the bootstrap randomization test that ?DesignFixedOptimal says is available.

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

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
